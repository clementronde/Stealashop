# Visuels du serveur Discord de Steal a Shop : icône, bannière, fond d'invitation, émojis, stickers, icônes de rôles,
# avatars de bots. Tout part de nos vrais assets (icône v3, logo, miniatures, ICON_ des objets, colis, icônes d'UI).
# Sortie : C:\Users\Charment\Documents\StealAShop-Art\Discord\ (fichiers prêts à téléverser + _apercus\).
# Lancer : py -I tools/clement/discord/discord_assets.py <groupe> [<groupe> ...]
#   groupes : icone, emojis, stickers, avatars, fonds, roles, tout
# Sources de la page du jeu (miniatures, icône, logo) : commit cab2645, extraites par
#   git archive cab2645 docs/claude/miniatures | tar -x -C <dossier>   puis   --mini <dossier>/docs/claude/miniatures
# Tailles vérifiées sur support.discord.com le 2026-11-23 (voir Discord\LISEZMOI_Discord.txt : où poser chaque fichier).
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ART = r"C:\Users\Charment\Documents\StealAShop-Art"
OUT = os.path.join(ART, "Discord")
# images refaites avec la vraie tenue du braqueur (session « vraie tenue », validées par Clément le 2026-11-23)
MINI_DEPOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "docs", "claude", "miniatures"))
TUILE_TENUE = os.path.join(MINI_DEPOT, "2026-11-21_logo", "embleme", "v_tenue", "chatgpt", "chatgpt_tuile_tenue.png")
TENUE_FINALES = os.path.join(MINI_DEPOT, "2026-11-23_ameliorations", "finales", "v_tenue", "chatgpt")
APERCUS = os.path.join(OUT, "_apercus")
FONTS = None  # dossier des polices de Roblox Studio, trouvé au lancement

CONTOUR = (4, 4, 53)  # #040435, contour des icônes ICON_
DC_SOMBRE = (49, 51, 56)  # fond de discussion de Discord, thème sombre
DC_LISTE = (30, 31, 34)  # colonne des serveurs, thème sombre
DC_CLAIR = (255, 255, 255)
DC_LISTE_CLAIR = (227, 229, 232)


def trouver_polices():
    base = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions")
    for v in sorted(os.listdir(base), reverse=True):
        f = os.path.join(base, v, "content", "fonts")
        if os.path.exists(os.path.join(f, "LuckiestGuy-Regular.ttf")):
            return f
    raise SystemExit("polices de Roblox Studio introuvables")


def police(nom, taille):
    return ImageFont.truetype(os.path.join(FONTS, nom), taille)


def net(im):
    return im.filter(ImageFilter.UnsharpMask(radius=1.0, percent=35, threshold=2))


def cercle(taille):
    m = Image.new("L", (taille * 4, taille * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, taille * 4 - 1, taille * 4 - 1), fill=255)
    return m.resize((taille, taille), Image.LANCZOS)


def en_rond(im, taille):
    r = im.convert("RGBA").resize((taille, taille), Image.LANCZOS)
    a = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    a.paste(r, (0, 0), cercle(taille))
    return a


def sauver(im, dossier, nom, **kw):
    os.makedirs(dossier, exist_ok=True)
    chemin = os.path.join(dossier, nom)
    im.save(chemin, optimize=True, **kw)
    return chemin, os.path.getsize(chemin)


# ---------------------------------------------------------------- icône du serveur
def groupe_icone(mini):
    # piste B (logo en tuile) choisie par Clément le 2026-11-23 ; la piste A (icône v3 du jeu) perdait la masse et la
    # Couronne au rognage rond
    pistes = {
        "Server": Image.open(TUILE_TENUE),
    }
    finies = {}
    for nom, im in pistes.items():
        im = im.convert("RGB")
        s = min(im.size)
        im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width - s) // 2 + s, (im.height - s) // 2 + s))
        im = net(im.resize((1024, 1024), Image.LANCZOS))
        finies[nom] = im
        print(sauver(im, os.path.join(OUT, "01_Icone_Serveur"), f"DISCORD_Icon_{nom}.png"))

    # aperçu : colonne des serveurs (48 px), carte d'invitation (~80 px), profil (128 px), thèmes sombre et clair
    W, H = 760, 300 * len(finies) + 20
    ap = Image.new("RGB", (W, H), (20, 20, 24))
    d = ImageDraw.Draw(ap)
    f = police("Montserrat-Bold.ttf", 18)
    for i, (nom, im) in enumerate(finies.items()):
        y0 = 20 + i * 300
        d.text((20, y0), nom, fill=(255, 255, 255), font=f)
        for j, (liste, fond) in enumerate(((DC_LISTE, DC_SOMBRE), (DC_LISTE_CLAIR, DC_CLAIR))):
            x0 = 20 + j * 370
            d.rectangle((x0, y0 + 30, x0 + 72, y0 + 280), fill=liste)
            d.rectangle((x0 + 72, y0 + 30, x0 + 350, y0 + 280), fill=fond)
            # colonne des serveurs : 3 icônes grises et la nôtre au milieu, en 48 px
            for k in range(4):
                yy = y0 + 46 + k * 58
                if k == 1:
                    ic = en_rond(im, 48)
                    ap.paste(ic, (x0 + 12, yy), ic)
                else:
                    d.ellipse((x0 + 12, yy, x0 + 60, yy + 48), fill=(88, 101, 242) if k == 0 else (90, 92, 100))
            for t, xx in ((80, x0 + 100), (128, x0 + 200)):
                ic = en_rond(im, t)
                ap.paste(ic, (xx, y0 + 60), ic)
    print(sauver(ap, APERCUS, "apercu_icone.png"))


# ---------------------------------------------------------------- icône animée (GIF, niveau 1 de boost)
def etoile(taille, couleur=(255, 255, 255)):
    """Étincelle à 4 branches, comme celles des miniatures (dessinée en 4x puis réduite)."""
    S = taille * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c, l, e = S / 2, S / 2, S * 0.09
    d.polygon([(c, c - l), (c + e, c - e), (c + l, c), (c + e, c + e), (c, c + l), (c - e, c + e), (c - l, c), (c - e, c - e)],
              fill=couleur + (255,))
    halo = im.filter(ImageFilter.GaussianBlur(S * 0.06))
    halo.alpha_composite(im)
    return halo.resize((taille, taille), Image.LANCZOS)


def groupe_icone_animee(mini):
    import math

    N, MS = 40, 50  # 40 images de 50 ms : une boucle de 2 s
    T = 512
    base = Image.open(TUILE_TENUE).convert("RGB")
    s = min(base.size)
    base = base.crop(((base.width - s) // 2, (base.height - s) // 2, (base.width - s) // 2 + s, (base.height - s) // 2 + s))
    base = net(base.resize((T, T), Image.LANCZOS))
    k = T / 1024  # les repères sont pris sur l'icône en 1024
    zone = tuple(int(v * k) for v in (150, 50, 690, 470))  # Couronne, halo et étincelles : seule partie qui bouge

    # masque de l'or de la Couronne (jaune vif, peu de bleu) dans sa boîte, et sa silhouette (tout sauf le ciel)
    px = base.load()
    or_ = Image.new("L", (T, T), 0)
    silhouette = Image.new("L", (T, T), 0)
    po, ps = or_.load(), silhouette.load()
    x0, y0, x1, y1 = (int(v * k) for v in (190, 85, 635, 445))
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = px[x, y]
            if not (b > r + 30 and b > 150):  # pas du ciel
                ps[x, y] = 255
            # l'or foncé du bas de la Couronne a la teinte des cheveux : on ne le prend qu'au-dessus des cheveux
            g_min = 95 if y < 372 * k else 160
            if (r > 180 and g > g_min and b < 130 and r >= g) or (r > 225 and g > 215 and b > 200):
                po[x, y] = 255
    or_ = or_.filter(ImageFilter.GaussianBlur(0.8))
    silhouette = silhouette.filter(ImageFilter.MaxFilter(3))
    anneau = Image.eval(silhouette.filter(ImageFilter.GaussianBlur(14 * k * 2)), lambda v: v)
    anneau = Image.composite(Image.new("L", (T, T), 0), anneau, silhouette)  # le halo autour, pas sur la Couronne

    etincelles = [  # (x, y en 1024, taille en 512, image de départ) : elles naissent l'une après l'autre
        (468, 112, 46, 4), (612, 300, 40, 12), (258, 168, 36, 20), (418, 290, 30, 28), (560, 160, 28, 34),
    ]
    images = []
    for i in range(N):
        t = i / N
        im = base.convert("RGBA")
        # 1. le halo violet de l'Épique qui respire
        a = 0.35 + 0.35 * (0.5 - 0.5 * math.cos(2 * math.pi * t))
        violet = Image.new("RGBA", (T, T), (190, 80, 255, 0))
        violet.putalpha(Image.eval(anneau, lambda v: int(v * a)))
        im.alpha_composite(violet)
        # 2. le reflet : une bande blanche en biais qui balaie l'or pendant les 0,7 premières secondes
        if t < 0.36:
            p = t / 0.36
            bande = Image.new("L", (T, T), 0)
            bd = ImageDraw.Draw(bande)
            cx = x0 - 120 * k + (x1 - x0 + 240 * k) * p
            w = 46 * k * 2
            bd.polygon([(cx - w, y1), (cx + w, y1), (cx + w + (y1 - y0) * 0.55, y0), (cx - w + (y1 - y0) * 0.55, y0)], fill=255)
            bande = bande.filter(ImageFilter.GaussianBlur(8 * k * 2))
            m = Image.eval(Image.composite(bande, Image.new("L", (T, T), 0), or_), lambda v: int(v * 0.92))
            blanc = Image.new("RGBA", (T, T), (255, 250, 225, 0))
            blanc.putalpha(m)
            im.alpha_composite(blanc)
        # 3. les étincelles : chacune grandit puis s'éteint en 10 images
        for ex, ey, taille, debut in etincelles:
            j = (i - debut) % N
            if j < 10:
                e = math.sin(math.pi * j / 10)
                tt = max(2, int(taille * e))
                st = etoile(tt)
                im.alpha_composite(st, (int(ex * k - tt / 2), int(ey * k - tt / 2)))
        images.append(im.convert("RGB"))

    # palette commune (fond + images les plus claires), tramage seulement dans la zone qui bouge : le reste ne
    # change jamais d'une image à l'autre, donc pas de scintillement et un GIF léger
    mosaique = Image.new("RGB", (T * 3, T))
    for n, im in enumerate((base, images[6], images[20])):
        mosaique.paste(im, (n * T, 0))
    pal = mosaique.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    fond_p = base.quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG)
    finies = []
    for im in images:
        f = fond_p.copy()
        f.paste(im.crop(zone).quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG), zone[:2])
        finies.append(f)
    dossier = os.path.join(OUT, "01_Icone_Serveur")
    chemin = os.path.join(dossier, "DISCORD_Icon_Server_Animated.gif")
    finies[0].save(chemin, save_all=True, append_images=finies[1:], duration=MS, loop=0, optimize=False, disposal=1)
    print(chemin, os.path.getsize(chemin), "octets,", N, "images de", MS, "ms")

    # aperçu : 6 images de la boucle en rond, et la taille de la colonne des serveurs
    ap = Image.new("RGB", (6 * 170 + 10, 190), DC_LISTE)
    for n, i in enumerate((0, 5, 10, 18, 26, 34)):
        r = en_rond(images[i], 160)
        ap.paste(r, (10 + n * 170, 15), r)
    print(sauver(ap, APERCUS, "apercu_icone_animee.png"))


# ---------------------------------------------------------------- émojis (128 × 128, < 256 Ko, nom = nom du fichier)
ITEMS = os.path.join(ART, "Items", "Icons")
BOXES = os.path.join(ART, "Boxes", "Icons", "ToImport")
COSM = os.path.join(ART, "Icons", "Cosmetics")
UI = os.path.join(ART, "UI")

EMOJIS = [
    # objets volés (ICON_ des objets, rendus Blender, contour #040435)
    ("crown", ITEMS, "ICON_Z4_Couronne.png"),
    ("diamond", ITEMS, "ICON_Z6_DiamantGeant.png"),
    ("goldbar", ITEMS, "ICON_Z6_LingotDOr.png"),
    ("goldpyramid", ITEMS, "ICON_Z6_PyramideDeLingots.png"),
    ("diamondbag", ITEMS, "ICON_Z6_SacDeDiamants.png"),
    ("diamondegg", ITEMS, "ICON_Z4_OeufEnDiamant.png"),
    ("goldthrone", ITEMS, "ICON_Z6_TroneEnOr.png"),
    ("goldbull", ITEMS, "ICON_Z6_TaureauEnOr.png"),
    ("safe", ITEMS, "ICON_Z6_CoffreFortBlinde.png"),
    ("gamingpc", ITEMS, "ICON_Z3_PcGamer.png"),
    ("monalisa", ITEMS, "ICON_Z5_LaJoconde.png"),
    ("meteorite", ITEMS, "ICON_Z5_Meteorite.png"),
    ("soda", ITEMS, "ICON_Z1_CanetteDeSoda.png"),
    ("donut", ITEMS, "ICON_Z1_Donut.png"),
    ("teddybear", ITEMS, "ICON_Z2_OursEnPeluche.png"),
    ("luckycat", ITEMS, "ICON_Secret_ChatPorteBonheurDore.png"),
    # colis, un par rareté
    ("box_common", BOXES, "ICON_BOX_Common.png"),
    ("box_uncommon", BOXES, "ICON_BOX_Uncommon.png"),
    ("box_rare", BOXES, "ICON_BOX_Rare.png"),
    ("box_epic", BOXES, "ICON_BOX_Epic.png"),
    ("box_legendary", BOXES, "ICON_BOX_Legendary.png"),
    ("box_mythic", BOXES, "ICON_BOX_Mythic.png"),
    ("box_secret", BOXES, "ICON_BOX_Secret.png"),
    ("box_divine", BOXES, "ICON_BOX_Divine.png"),
    # auras et trails
    ("aura_fire", COSM, "ICON_Aura_Feu.png"),
    ("aura_lightning", COSM, "ICON_Aura_Eclair.png"),
    ("aura_angel", COSM, "ICON_Aura_Angel.png"),
    ("aura_demon", COSM, "ICON_Aura_Demon.png"),
    ("trail_comet", COSM, "ICON_Trail_Comete.png"),
    # icônes de l'UI du jeu
    ("cash", os.path.join(UI, "_A_importer"), "UI_Icon_Cash.png"),
    ("speed", os.path.join(UI, "_A_importer"), "UI_Icon_Speed.png"),
    ("strength", os.path.join(UI, "_A_importer"), "UI_Icon_Strength.png"),
    ("rebirth", os.path.join(UI, "_A_importer"), "UI_Icon_Rebirth.png"),
    ("hammer", os.path.join(UI, "_A_importer"), "UI_Icon_Damage.png"),
    ("night", os.path.join(UI, "_A_importer"), "UI_Icon_Moon.png"),
    ("vip", os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_GP_VIP.png"),
    ("gift", os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_Gift.png"),
    ("locked", os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_Lock.png"),
    ("warning", os.path.join(UI, "_A_importer_notify"), "UI_Icon_Warning.png"),
]


def rogner(im, marge=0.02):
    """Coupe le vide transparent autour de l'objet, puis le met au centre d'un carré (petite marge)."""
    im = im.convert("RGBA")
    boite = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if boite:
        im = im.crop(boite)
    c = int(max(im.size) * (1 + 2 * marge))
    carre = Image.new("RGBA", (c, c), (0, 0, 0, 0))
    carre.paste(im, ((c - im.width) // 2, (c - im.height) // 2), im)
    return carre


def petit(im, taille):
    """Réduction propre d'une image avec transparence (alpha prémultiplié, sinon des franges claires)."""
    pm = im.convert("RGBa").resize((taille, taille), Image.LANCZOS)
    return net(pm.convert("RGBA"))


def groupe_emojis():
    # première version (objets, colis, auras, UI) : non retenue par Clément le 2026-11-23, gardée à part
    dossier = os.path.join(OUT, "_non_retenus", "emojis_objets")
    faits = []
    for nom, base, fichier in EMOJIS:
        im = petit(rogner(Image.open(os.path.join(base, fichier))), 128)
        chemin, poids = sauver(im, dossier, f"{nom}.png")
        assert poids < 256 * 1024, (nom, poids)
        faits.append((nom, im))
    print(len(faits), "émojis dans", dossier)

    # aperçu : chaque émoji en 22 px (dans une ligne de texte) et en 48 px (émoji seul), thème sombre puis clair
    cols, case = 8, 96
    rangs = (len(faits) + cols - 1) // cols
    ap = Image.new("RGB", (cols * case * 2 + 30, rangs * case + 20), DC_SOMBRE)
    d = ImageDraw.Draw(ap)
    ImageDraw.Draw(ap).rectangle((cols * case + 15, 0, ap.width, ap.height), fill=DC_CLAIR)
    f = police("Montserrat-Medium.ttf", 11)
    for i, (nom, im) in enumerate(faits):
        for j, (fond, encre) in enumerate(((DC_SOMBRE, (219, 222, 225)), (DC_CLAIR, (49, 51, 56)))):
            x = 10 + j * (cols * case + 15) + (i % cols) * case
            y = 10 + (i // cols) * case
            g = im.resize((48, 48), Image.LANCZOS)
            ap.paste(g, (x + 4, y), g)
            p = im.resize((22, 22), Image.LANCZOS)
            ap.paste(p, (x + 60, y + 13), p)
            d.text((x + 2, y + 54), f":{nom}:", fill=encre, font=f)
    print(sauver(ap, APERCUS, "apercu_emojis.png"))


# ---------------------------------------------------------------- stickers (320 × 320 exact, PNG, < 512 Ko)
def texte_contour(taille_img, texte, fnt, remplissage, contour=CONTOUR, epaisseur=10, centre=None, arc_en_ciel=False):
    """Texte du jeu : lettres pleines (ou en arc-en-ciel), gros contour #040435, petite ombre en bas."""
    calque = Image.new("RGBA", taille_img, (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    cx, cy = centre or (taille_img[0] // 2, taille_img[1] // 2)
    d.text((cx, cy + epaisseur // 2), texte, font=fnt, anchor="mm", fill=contour, stroke_width=epaisseur, stroke_fill=contour)
    d.text((cx, cy), texte, font=fnt, anchor="mm", fill=contour, stroke_width=epaisseur, stroke_fill=contour)
    masque = Image.new("L", taille_img, 0)
    ImageDraw.Draw(masque).text((cx, cy), texte, font=fnt, anchor="mm", fill=255)
    if arc_en_ciel:
        boite = masque.getbbox()
        couleurs = [(255, 59, 92), (255, 140, 26), (255, 214, 10), (53, 201, 59), (46, 166, 242), (155, 91, 246)]
        degrade = Image.new("RGBA", taille_img)
        dd = ImageDraw.Draw(degrade)
        x0, x1 = boite[0], boite[2]
        for x in range(taille_img[0]):
            t = min(max((x - x0) / max(1, x1 - x0), 0), 0.9999) * (len(couleurs) - 1)
            a, b = couleurs[int(t)], couleurs[int(t) + 1]
            k = t - int(t)
            dd.line((x, 0, x, taille_img[1]), fill=tuple(int(a[n] + (b[n] - a[n]) * k) for n in range(3)) + (255,))
        calque.paste(degrade, (0, 0), masque)
    else:
        haut, bas = remplissage
        boite = masque.getbbox()
        degrade = Image.new("RGBA", taille_img)
        dd = ImageDraw.Draw(degrade)
        for y in range(taille_img[1]):
            t = min(max((y - boite[1]) / max(1, boite[3] - boite[1]), 0), 1)
            dd.line((0, y, taille_img[0], y), fill=tuple(int(haut[n] + (bas[n] - haut[n]) * t) for n in range(3)) + (255,))
        calque.paste(degrade, (0, 0), masque)
    return calque


def poser(fond, im, boite):
    """Pose une image RGBA dans une boîte (x0, y0, x1, y1), à l'échelle, centrée."""
    x0, y0, x1, y1 = boite
    im = rogner(im, 0)
    k = min((x1 - x0) / im.width, (y1 - y0) / im.height)
    im = im.convert("RGBa").resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS).convert("RGBA")
    fond.alpha_composite(im, (x0 + (x1 - x0 - im.width) // 2, y0 + (y1 - y0 - im.height) // 2))


def decoupe(im, taille=320, liseré=8):
    """Finition « sticker découpé » : le dessin remplit la case, entouré d'un liseré blanc de 8 px."""
    im = rogner(im, 0)
    k = (taille - 2 * liseré - 4) / max(im.size)
    im = im.convert("RGBa").resize((int(im.width * k), int(im.height * k)), Image.LANCZOS).convert("RGBA")
    case = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    case.paste(im, ((taille - im.width) // 2, (taille - im.height) // 2), im)
    a = case.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    for _ in range(liseré // 2):
        a = a.filter(ImageFilter.MaxFilter(5))
    a = a.filter(ImageFilter.GaussianBlur(0.8))
    fond = Image.new("RGBA", (taille, taille), (255, 255, 255, 0))
    fond.putalpha(a)
    fond.alpha_composite(case)
    return fond


def groupe_stickers():
    # première version (icônes de l'UI et texte) : remplacée par les stickers ChatGPT, gardée à part
    dossier = os.path.join(OUT, "_non_retenus", "stickers_v1")
    S = (320, 320)
    lg = lambda t: police("LuckiestGuy-Regular.ttf", t)
    blanc = ((255, 255, 255), (214, 222, 255))
    or_ = ((255, 236, 120), (255, 160, 10))
    faits = []

    # 1. le logo du jeu (celui de l'écran de chargement)
    s = Image.new("RGBA", S, (0, 0, 0, 0))
    poser(s, Image.open(os.path.join(UI, "Loading", "UI_Loading_Logo.png")), (6, 40, 314, 280))
    faits.append(("stealashop", s))

    # 2. « MINE! » sur la Couronne
    s = Image.new("RGBA", S, (0, 0, 0, 0))
    poser(s, Image.open(os.path.join(ITEMS, "ICON_Z4_Couronne.png")), (20, 8, 300, 228))
    s.alpha_composite(texte_contour(S, "MINE!", lg(92), or_, epaisseur=12, centre=(160, 258)))
    faits.append(("mine", s))

    # 3. l'argent du jeu en arc-en-ciel, au-dessus de la liasse
    s = Image.new("RGBA", S, (0, 0, 0, 0))
    poser(s, Image.open(os.path.join(UI, "_A_importer", "UI_Icon_Cash.png")), (60, 20, 260, 190))
    s.alpha_composite(texte_contour(S, "+$999T/s", lg(64), None, epaisseur=10, centre=(160, 250), arc_en_ciel=True))
    faits.append(("cashflow", s))

    # 4. « BUSTED! » : le panneau d'alerte du jeu
    s = Image.new("RGBA", S, (0, 0, 0, 0))
    poser(s, Image.open(os.path.join(UI, "_A_importer_notify", "UI_Icon_Warning.png")), (70, 10, 250, 190))
    s.alpha_composite(texte_contour(S, "BUSTED!", lg(76), ((255, 120, 120), (220, 40, 50)), epaisseur=11, centre=(160, 250)))
    faits.append(("busted", s))

    # 5. le colis Secret qui s'ouvre : « ??? » arc-en-ciel
    s = Image.new("RGBA", S, (0, 0, 0, 0))
    poser(s, Image.open(os.path.join(BOXES, "ICON_BOX_Secret.png")), (24, 70, 296, 300))
    s.alpha_composite(texte_contour(S, "SECRET!", lg(70), None, epaisseur=10, centre=(160, 52), arc_en_ciel=True))
    faits.append(("secret", s))

    faits = [(nom, decoupe(im)) for nom, im in faits]
    for nom, im in faits:
        chemin, poids = sauver(im, dossier, f"{nom}.png")
        assert im.size == S and poids < 512 * 1024, (nom, im.size, poids)
    print(len(faits), "stickers dans", dossier)

    # aperçu : taille d'affichage dans la discussion (160 px), thème sombre puis clair
    ap = Image.new("RGB", (len(faits) * 176 + 16, 2 * 196 + 16), DC_SOMBRE)
    d = ImageDraw.Draw(ap)
    d.rectangle((0, 196 + 8, ap.width, ap.height), fill=DC_CLAIR)
    f = police("Montserrat-Medium.ttf", 12)
    for i, (nom, im) in enumerate(faits):
        for j, encre in enumerate(((219, 222, 225), (49, 51, 56))):
            x, y = 16 + i * 176, 12 + j * 204
            p = im.resize((160, 160), Image.LANCZOS)
            ap.paste(p, (x, y), p)
            d.text((x, y + 166), nom, fill=encre, font=f)
    print(sauver(ap, APERCUS, "apercu_stickers.png"))


# ---------------------------------------------------------------- avatars des bots et webhooks (carré, affiché en rond)
AVATARS = [
    # nom, image (relative à miniatures/2026-11-23_ameliorations, ou chemin absolu), carré (x0, y0, côté)
    ("Guard", "chatgpt/03_retouche.png", (1238, 70, 430)),
    # miniature 11 refaite avec la vraie tenue du braqueur (session « vraie tenue », 2026-11-23)
    ("GuardNight", os.path.join(TENUE_FINALES, "11_tenue.png"), (150, 50, 450)),
    ("Robber", os.path.join(TENUE_FINALES, "11_tenue.png"), (900, 40, 560)),
]


def groupe_avatars(mini):
    dossier = os.path.join(OUT, "05_Avatars_Bots")
    faits = []
    for nom, src, (x, y, c) in AVATARS:
        im = Image.open(os.path.join(mini, "2026-11-23_ameliorations", src)).convert("RGB")
        im = net(im.crop((x, y, x + c, y + c)).resize((512, 512), Image.LANCZOS))
        print(sauver(im, dossier, f"AVATAR_{nom}.png"))
        faits.append((nom, im))
    # aperçu : à 40 px (message) et 80 px (profil), en rond
    ap = Image.new("RGB", (len(faits) * 150 + 20, 160), DC_SOMBRE)
    d = ImageDraw.Draw(ap)
    f = police("Montserrat-Bold.ttf", 13)
    for i, (nom, im) in enumerate(faits):
        x = 20 + i * 150
        for t, yy, xx in ((80, 14, x), (40, 34, x + 90)):
            r = en_rond(im, t)
            ap.paste(r, (xx, yy), r)
        d.text((x, 112), nom, fill=(255, 255, 255), font=f)
    print(sauver(ap, APERCUS, "apercu_avatars.png"))


# ---------------------------------------------------------------- bannière, fond d'invitation, fond de découverte (16:9)
FONDS = [
    # nom, dossier de sortie, image (chemin absolu), zoom (facteur, ancre x, ancre y)
    # (la bannière n'est plus ici : c'est la rue des 6 zones, groupe banniere_rue)
    # sources : miniatures 31 et 22 refaites avec la vraie tenue du braqueur (2026-11-23)
    # zoom : le braqueur à gauche et le vigile à droite de la fenêtre d'invitation, qui cache le milieu
    ("DISCORD_InviteBackground", "04_Fonds", os.path.join(TENUE_FINALES, "31_tenue.png"), (1.35, 0.18, 0.25)),
    ("DISCORD_DiscoverySplash", "04_Fonds", os.path.join(TENUE_FINALES, "22_tenue.png"), None),
]


def groupe_fonds(mini):
    faits = {}
    for nom, sous, src, zoom in FONDS:
        im = Image.open(os.path.join(mini, "2026-11-23_ameliorations", src)).convert("RGB")
        if zoom:
            z, ax, ay = zoom
            cw, ch = im.width / z, im.height / z
            x0, y0 = ax * (im.width - cw), ay * (im.height - ch)
            im = im.crop((int(x0), int(y0), int(x0 + cw), int(y0 + ch)))
        im = net(im.resize((1920, 1080), Image.LANCZOS))  # 1920 × 1080 : exigé pour l'invitation, accepté ailleurs
        print(sauver(im, os.path.join(OUT, sous), f"{nom}.jpg", quality=92))
        faits[nom] = im
    f_titre = police("Montserrat-Bold.ttf", 15)
    f_txt = police("Montserrat-Medium.ttf", 13)

    # aperçu invitation : la fenêtre d'invitation verticale au milieu (fond réduit de moitié)
    inv = faits["DISCORD_InviteBackground"].resize((960, 540), Image.LANCZOS)
    d = ImageDraw.Draw(inv)
    d.rounded_rectangle((360, 110, 600, 430), radius=8, fill=DC_SOMBRE)
    d.ellipse((440, 140, 520, 220), fill=(90, 92, 100))
    d.text((480, 240), "Steal a Shop", fill=(255, 255, 255), font=f_titre, anchor="mm")
    d.rounded_rectangle((380, 380, 580, 414), radius=4, fill=(88, 101, 242))
    d.text((480, 397), "Accept Invite", fill=(255, 255, 255), font=f_txt, anchor="mm")
    print(sauver(inv, APERCUS, "apercu_invitation.png"))


# ---------------------------------------------------------------- rôles : icônes 64 × 64 (< 256 Ko) et couleurs
ROLES = [
    # nom du rôle, couleur (palette MOD-002), image de l'icône (None = pas d'icône)
    ("Owner", "#FFC52E", (os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_Crown.png")),
    ("Developer", "#2EA6F2", (os.path.join(UI, "_A_importer"), "UI_Icon_Damage.png")),
    ("Moderator", "#35C93B", (os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_Lock.png")),
    ("Tester", "#FF8C1A", (os.path.join(UI, "_A_importer_settings"), "UI_Icon_Settings.png")),
    ("Content Creator", "#F04FA5", (os.path.join(UI, "_A_importer_inventaire"), "UI_Icon_Star.png")),
    ("VIP", "#9B5CF6", (os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_GP_VIP.png")),
    ("Server Booster", "#F47FFF", (os.path.join(UI, "_A_importer_ecrans"), "UI_Icon_Zone4.png")),
    # paliers d'activité aux couleurs des raretés, avec le colis de la rareté
    ("Secret", "#FFFFFF", (BOXES, "ICON_BOX_Secret.png")),
    ("Mythic", "#FF3B5C", (BOXES, "ICON_BOX_Mythic.png")),
    ("Legendary", "#FFC21A", (BOXES, "ICON_BOX_Legendary.png")),
    ("Epic", "#A855F7", (BOXES, "ICON_BOX_Epic.png")),
    ("Rare", "#2F9BFF", (BOXES, "ICON_BOX_Rare.png")),
    ("Uncommon", "#2FE08F", (BOXES, "ICON_BOX_Uncommon.png")),
    ("Common", "#B0B7C3", (BOXES, "ICON_BOX_Common.png")),
]


def hexa(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def groupe_roles():
    dossier = os.path.join(OUT, "06_Icones_Roles")
    faits = []
    for nom, couleur, (base, fichier) in ROLES:
        im = petit(rogner(Image.open(os.path.join(base, fichier))), 64)
        chemin, poids = sauver(im, dossier, f"ROLE_{nom.replace(' ', '')}.png")
        assert im.size == (64, 64) and poids < 256 * 1024
        faits.append((nom, couleur, im))
    print(len(faits), "icônes de rôles dans", dossier)

    # aperçu : liste des membres (nom en couleur du rôle + icône 18 px) et une ligne de discussion
    f_nom = police("Montserrat-Bold.ttf", 15)
    f_tete = police("Montserrat-Bold.ttf", 11)
    f_txt = police("Montserrat-Medium.ttf", 15)
    ap = Image.new("RGB", (620, 30 + len(faits) * 44), DC_SOMBRE)
    d = ImageDraw.Draw(ap)
    d.rectangle((0, 0, 250, ap.height), fill=(43, 45, 49))
    for i, (nom, couleur, im) in enumerate(faits):
        y = 14 + i * 44
        d.text((14, y), f"{nom.upper()} — 1", fill=(148, 155, 164), font=f_tete)
        d.ellipse((14, y + 15, 40, y + 41), fill=(90, 92, 100))
        d.text((48, y + 19), nom, fill=hexa(couleur), font=f_nom)
        w = d.textlength(nom, font=f_nom)
        ic = im.resize((18, 18), Image.LANCZOS)
        ap.paste(ic, (int(52 + w), y + 20), ic)
        # ligne de discussion à droite
        d.text((270, y + 12), nom, fill=hexa(couleur), font=f_nom)
        w = d.textlength(nom, font=f_nom)
        ap.paste(ic, (int(274 + w), y + 13), ic)
        d.text((int(300 + w), y + 12), "gg !", fill=(219, 222, 225), font=f_txt)
    print(sauver(ap, APERCUS, "apercu_roles.png"))


# ---------------------------------------------------------------- planches ChatGPT (émojis et stickers des persos)
# Clément, 2026-11-23 : des émojis « en rapport avec le jeu », faits avec ChatGPT : les réactions du braqueur et du
# vigile. Planches générées dans son Chrome (référence jointe : le braqueur du logo et le vigile des miniatures),
# téléchargées avec son accord dans Discord\_chatgpt\.
EMOJIS_PERSOS = [  # planche 4 × 3, de gauche à droite puis de haut en bas
    "robber_lol", "robber_cry", "robber_shock", "robber_money",
    "robber_thumbsup", "robber_sneaky", "robber_rage", "robber_run",
    "guard_shock", "guard_angry", "guard_sleep", "guard_busted",
]


def sans_fond_blanc(im, seuil=60):
    """Retire le fond blanc relié aux bords (remplissage), garde le blanc enfermé dans le contour (yeux, dents)."""
    im = im.convert("RGB")
    cle = (255, 0, 255)
    travail = im.copy()
    w, h = travail.size
    for x in range(0, w, 16):
        for y in (0, h - 1):
            if sum(travail.getpixel((x, y))) > 3 * 225:
                ImageDraw.floodfill(travail, (x, y), cle, thresh=seuil)
    for y in range(0, h, 16):
        for x in (0, w - 1):
            if sum(travail.getpixel((x, y))) > 3 * 225:
                ImageDraw.floodfill(travail, (x, y), cle, thresh=seuil)
    fond = Image.new("L", (w, h), 0)
    pt, pf = travail.load(), fond.load()
    for y in range(h):
        for x in range(w):
            if pt[x, y] == cle:
                pf[x, y] = 255
    # les grands vides blancs entre les cases sont reliés aux bords ; un vide fermé de la grille ne l'est pas,
    # d'où un second remplissage depuis chaque pixel très clair voisin du fond déjà trouvé (pas nécessaire ici)
    alpha = Image.eval(fond, lambda v: 255 - v).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.9))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def bandes(profil, minimum=6):
    """Indices [début, fin) des groupes de colonnes (ou de lignes) qui contiennent du dessin."""
    groupes, debut = [], None
    for i, v in enumerate(profil + [0]):
        if v and debut is None:
            debut = i
        elif not v and debut is not None:
            if i - debut >= minimum:
                groupes.append([debut, i])
            debut = None
    return groupes


def fusionner(groupes, n):
    """Réduit la liste de bandes à n en fusionnant les écarts les plus petits (une larme détachée, des « Z »)."""
    while len(groupes) > n:
        ecarts = [groupes[i + 1][0] - groupes[i][1] for i in range(len(groupes) - 1)]
        i = ecarts.index(min(ecarts))
        groupes[i] = [groupes[i][0], groupes[i + 1][1]]
        del groupes[i + 1]
    return groupes


def decouper_grille(im, colonnes, lignes):
    """colonnes : un nombre pour toutes les lignes, ou une liste (une valeur par ligne)."""
    a = im.getchannel("A").point(lambda v: 255 if v > 60 else 0)
    w, h = a.size
    px = a.load()
    rangs = fusionner(bandes([1 if any(px[x, y] for x in range(0, w, 2)) else 0 for y in range(h)]), lignes)
    par_ligne = colonnes if isinstance(colonnes, list) else [colonnes] * lignes
    cases = []
    for (y0, y1), n in zip(rangs, par_ligne):
        encre = [sum(1 for y in range(y0, y1, 2) if px[x, y]) for x in range(w)]
        cols = fusionner(bandes([1 if v else 0 for v in encre]), n)
        while len(cols) < n:  # deux dessins qui se touchent : coupe la bande la plus large là où il y a le moins d'encre
            k = max(range(len(cols)), key=lambda i: cols[i][1] - cols[i][0])
            a0, a1 = cols[k]
            lo, hi = a0 + (a1 - a0) // 5, a1 - (a1 - a0) // 5
            xc = min(range(lo, hi), key=lambda x: encre[x])
            cols[k:k + 1] = [[a0, xc], [xc, a1]]
        for x0, x1 in cols:
            cases.append(im.crop((x0, y0, x1, y1)))
    return cases


def groupe_chatgpt_emojis():
    src = os.path.join(OUT, "_chatgpt", "chatgpt_emojis_v3_beige.png")
    cases = decouper_grille(sans_fond_blanc(Image.open(src)), 4, 3)
    assert len(cases) == len(EMOJIS_PERSOS), len(cases)
    dossier = os.path.join(OUT, "02_Emojis")
    faits = []
    for nom, im in zip(EMOJIS_PERSOS, cases):
        e = petit(rogner(im), 128)
        chemin, poids = sauver(e, dossier, f"{nom}.png")
        assert poids < 256 * 1024
        faits.append((nom, e))
    print(len(faits), "émojis des persos dans", dossier)
    cols, case = 6, 96
    rangs = (len(faits) + cols - 1) // cols
    ap = Image.new("RGB", (cols * case * 2 + 30, rangs * case + 20), DC_SOMBRE)
    d = ImageDraw.Draw(ap)
    d.rectangle((cols * case + 15, 0, ap.width, ap.height), fill=DC_CLAIR)
    f = police("Montserrat-Medium.ttf", 11)
    for i, (nom, im) in enumerate(faits):
        for j, encre in enumerate(((219, 222, 225), (49, 51, 56))):
            x = 10 + j * (cols * case + 15) + (i % cols) * case
            y = 10 + (i // cols) * case
            g = im.resize((48, 48), Image.LANCZOS)
            ap.paste(g, (x + 4, y), g)
            p = im.resize((22, 22), Image.LANCZOS)
            ap.paste(p, (x + 60, y + 13), p)
            d.text((x + 2, y + 54), f":{nom}:", fill=encre, font=f)
    print(sauver(ap, APERCUS, "apercu_emojis_persos.png"))


STICKERS_PERSOS = [  # planche 3 + 2 ; texte posé ici avec la police du jeu (Luckiest Guy, contour #040435)
    ("mine", "MINE!", "or"),
    ("cashflow", "+$999T/s", "arc"),
    ("busted", "BUSTED!", "rouge"),
    ("secret", "SECRET!", "arc"),
    ("stealashop", None, "logo"),
]


def groupe_chatgpt_stickers():
    src = os.path.join(OUT, "_chatgpt", "chatgpt_stickers_v3_beige.png")
    cases = decouper_grille(sans_fond_blanc(Image.open(src)), [3, 2], 2)
    assert len(cases) == len(STICKERS_PERSOS), len(cases)
    S = (320, 320)
    teintes = {"or": ((255, 236, 120), (255, 160, 10)), "rouge": ((255, 120, 120), (220, 40, 50))}
    dossier = os.path.join(OUT, "03_Stickers")
    faits = []
    for (nom, texte, style), perso in zip(STICKERS_PERSOS, cases):
        s = Image.new("RGBA", S, (0, 0, 0, 0))
        if style == "logo":
            poser(s, perso, (50, 0, 270, 180))
            poser(s, Image.open(os.path.join(UI, "Loading", "UI_Loading_Logo.png")), (4, 150, 316, 318))
        else:
            poser(s, perso, (14, 0, 306, 236))
            taille = 74 if len(texte) <= 7 else 58
            s.alpha_composite(texte_contour(S, texte, police("LuckiestGuy-Regular.ttf", taille), teintes.get(style),
                                            epaisseur=11, centre=(160, 262), arc_en_ciel=(style == "arc")))
        s = decoupe(s)
        chemin, poids = sauver(s, dossier, f"{nom}.png")
        assert s.size == S and poids < 512 * 1024, (nom, poids)
        faits.append((nom, s))
    print(len(faits), "stickers dans", dossier)
    ap = Image.new("RGB", (len(faits) * 176 + 16, 2 * 196 + 16), DC_SOMBRE)
    d = ImageDraw.Draw(ap)
    d.rectangle((0, 196 + 8, ap.width, ap.height), fill=DC_CLAIR)
    f = police("Montserrat-Medium.ttf", 12)
    for i, (nom, im) in enumerate(faits):
        for j, encre in enumerate(((219, 222, 225), (49, 51, 56))):
            x, y = 16 + i * 176, 12 + j * 204
            p = im.resize((160, 160), Image.LANCZOS)
            ap.paste(p, (x, y), p)
            d.text((x, y + 166), nom, fill=encre, font=f)
    print(sauver(ap, APERCUS, "apercu_stickers.png"))


def groupe_chatgpt_banniere():
    """Bannière refaite par ChatGPT avec la vraie tenue (2026-11-23) : 16:9 exact, 1920 × 1080 et 960 × 540."""
    im = Image.open(os.path.join(OUT, "_chatgpt", "chatgpt_banniere.png")).convert("RGB")
    w, h = im.size
    if w / h > 16 / 9:  # trop large : on coupe les côtés
        nw = int(h * 16 / 9)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:  # trop haut : on coupe surtout le bas (le haut est le ciel où s'écrit le nom du serveur)
        nh = int(w * 9 / 16)
        haut = (h - nh) // 3
        im = im.crop((0, haut, w, haut + nh))
    dossier = os.path.join(OUT, "04_Fonds")
    grand = net(im.resize((1920, 1080), Image.LANCZOS))
    print(sauver(grand, dossier, "DISCORD_Banner.jpg", quality=92))
    print(sauver(net(im.resize((960, 540), Image.LANCZOS)), dossier, "DISCORD_Banner_960x540.jpg", quality=92))

    f_titre = police("Montserrat-Bold.ttf", 15)
    f_txt = police("Montserrat-Medium.ttf", 13)
    ap = Image.new("RGB", (560, 420), DC_LISTE)
    d = ImageDraw.Draw(ap)
    d.rectangle((72, 0, 312, 420), fill=(43, 45, 49))
    d.rectangle((312, 0, 560, 420), fill=DC_SOMBRE)
    b = grand.resize((240, 135), Image.LANCZOS).convert("RGBA")
    voile = Image.new("RGBA", (240, 135), (0, 0, 0, 0))
    vd = ImageDraw.Draw(voile)
    for y in range(48):
        vd.line((0, y, 240, y), fill=(0, 0, 0, int(110 * (1 - y / 48))))
    b.alpha_composite(voile)
    ap.paste(b, (72, 0))
    d.text((84, 14), "Steal a Shop", fill=(255, 255, 255), font=f_titre)
    for k, s in enumerate(("# rules", "# announcements", "# updates", "# welcome", "# general")):
        d.text((88, 150 + k * 28), s, fill=(148, 155, 164), font=f_txt)
    for k in range(5):
        d.ellipse((12, 12 + k * 58, 60, 60 + k * 58), fill=(90, 92, 100))
    print(sauver(ap, APERCUS, "apercu_banniere.png"))


def groupe_banniere_rue(centre_y=0.52, remonter=0.085):
    """Bannière 680 × 240 (taille donnée par Clément le 2026-11-23), une autre scène que le logo : la rue des
    6 zones. Discord n'en montre que la bande du milieu (~6:1, de 26 % à 74 % de la hauteur) : la scène est remontée
    de `remonter` (ciel coupé en haut, route prolongée en bas par le reflet du bitume) pour que les enseignes et les
    persos, de la tête aux pieds, tombent dans cette bande."""
    im = Image.open(os.path.join(OUT, "_chatgpt", "chatgpt_banniere_rue.png")).convert("RGB")
    w, h = im.size
    if remonter:
        dh = int(h * remonter)
        bas = im.crop((0, h - dh, w, h)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        neuf = Image.new("RGB", (w, h))
        neuf.paste(im.crop((0, dh, w, h)), (0, 0))
        neuf.paste(bas, (0, h - dh))
        im = neuf
    ratio = 680 / 240
    if w / h > ratio:
        nw = int(h * ratio)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / ratio)
        y0 = min(max(int(h * centre_y - nh / 2), 0), h - nh)
        im = im.crop((0, y0, w, y0 + nh))
    dossier = os.path.join(OUT, "04_Fonds")
    # le fichier à poser : la pleine résolution de ChatGPT (Discord réduit lui-même ; un 680 × 240 agrandi sort flou)
    print(sauver(im, dossier, f"DISCORD_Banner_{im.width}x{im.height}.png"), "(à poser)")
    print(sauver(net(im.resize((680, 240), Image.LANCZOS)), dossier, "DISCORD_Banner_680x240.png"))

    # aperçu de la bande que Discord affiche en haut du serveur (capture de Clément : ~1396 × 234, soit ~6:1,
    # prise au milieu de la hauteur), avec l'icône et le nom posés en bas à gauche
    bw, bh = 1396, 234
    k = bw / im.width
    haut = int((im.height * k - bh) / 2)
    bande = im.resize((bw, int(im.height * k)), Image.LANCZOS).crop((0, haut, bw, haut + bh)).convert("RGBA")
    voile = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    vd = ImageDraw.Draw(voile)
    for y in range(bh // 2, bh):
        vd.line((0, y, bw, y), fill=(0, 0, 0, int(150 * (y - bh // 2) / (bh // 2))))
    bande.alpha_composite(voile)
    icone = Image.open(os.path.join(OUT, "01_Icone_Serveur", "DISCORD_Icon_Server.png")).convert("RGBA").resize((50, 50), Image.LANCZOS)
    bande.alpha_composite(icone, (18, bh - 68))
    d = ImageDraw.Draw(bande)
    d.text((80, bh - 64), "Steal a Shop", fill=(255, 255, 255), font=police("Montserrat-Bold.ttf", 18))
    d.text((80, bh - 36), "5 en ligne  ·  4 membres  ·  0 Boost", fill=(210, 214, 220), font=police("Montserrat-Medium.ttf", 12))
    ap = Image.new("RGB", (bw + 20, bh + 20), DC_LISTE)
    ap.paste(bande.convert("RGB"), (10, 10))
    print(sauver(ap, APERCUS, "apercu_banniere_bande_discord.png"))


def main():
    global FONTS
    p = argparse.ArgumentParser()
    p.add_argument("groupes", nargs="+")
    p.add_argument("--mini", help="dossier docs/claude/miniatures extrait du commit cab2645")
    a = p.parse_args()
    FONTS = trouver_polices()
    g = set(a.groupes)
    tout = "tout" in g
    if tout or "icone" in g:
        groupe_icone(a.mini)
    if tout or "icone_animee" in g:
        groupe_icone_animee(a.mini)
    if tout or "emojis" in g:
        groupe_emojis()
    if tout or "stickers" in g:
        groupe_stickers()
    if tout or "avatars" in g:
        groupe_avatars(a.mini)
    if tout or "fonds" in g:
        groupe_fonds(a.mini)
    if tout or "roles" in g:
        groupe_roles()
    if tout or "chatgpt_emojis" in g:
        groupe_chatgpt_emojis()
    if tout or "chatgpt_stickers" in g:
        groupe_chatgpt_stickers()
    if tout or "chatgpt_banniere" in g:
        groupe_chatgpt_banniere()
    if tout or "banniere_rue" in g:
        groupe_banniere_rue()


if __name__ == "__main__":
    main()

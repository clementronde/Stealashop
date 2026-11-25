# Gabarit de chemise classique Roblox (585 x 559) du bacon hair des trailers :
# veste noire ouverte a manches courtes sur un t-shirt bleu vif avec une moto noire.
# Sert seulement aux faux joueurs du tournage (Workspace/_TRAILER), en local :
#   python make_shirt_baconhair.py <sortie.png>
# puis copier le PNG dans %LOCALAPPDATA%\Roblox\Versions\<version de Studio>\content\textures\StealAShopTrailer\
# et utiliser rbxasset://textures/StealAShopTrailer/shirt_baconhair.png (ne marche que sur ce PC).
import sys
from PIL import Image, ImageDraw

W, H = 585, 559
BLUE = (38, 140, 226, 255)
BLUE_D = (28, 112, 190, 255)
JACKET = (26, 26, 28, 255)
JACKET_L = (44, 44, 48, 255)
SEAM = (12, 12, 14, 255)
MOTO = (14, 22, 34, 255)

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def rect(x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def jacket_shade(x, y, w, h):
    # aplat noir avec un leger degrade vertical, comme le cuir du modele de reference
    for i in range(h):
        t = i / max(1, h - 1)
        c = tuple(int(JACKET_L[k] * (1 - t) + JACKET[k] * t) for k in range(3)) + (255,)
        d.line([x, y + i, x + w - 1, y + i], fill=c)


# --- Torse ---------------------------------------------------------------
# dessus (epaules) et dessous
jacket_shade(231, 8, 128, 64)
rect(231 + 44, 8 + 40, 40, 24, BLUE)  # col du t-shirt vu d'en haut
jacket_shade(231, 204, 128, 64)
rect(231 + 40, 204, 48, 64, BLUE_D)
# cotes et dos : veste
jacket_shade(165, 74, 64, 128)
jacket_shade(361, 74, 64, 128)
jacket_shade(427, 74, 128, 128)
d.line([427 + 64, 74, 427 + 64, 74 + 127], fill=SEAM, width=2)  # couture du dos
# face avant : t-shirt bleu au milieu, pans de veste ouverts de chaque cote
FX, FY = 231, 74
rect(FX, FY, 128, 128, BLUE)
jacket_shade(FX, FY, 34, 128)
jacket_shade(FX + 128 - 34, FY, 34, 128)
# revers de la veste (petit triangle vers le col)
d.polygon([(FX + 34, FY), (FX + 46, FY), (FX + 34, FY + 26)], fill=JACKET)
d.polygon([(FX + 94, FY), (FX + 82, FY), (FX + 94, FY + 26)], fill=JACKET)
d.line([FX + 34, FY, FX + 34, FY + 127], fill=SEAM, width=2)
d.line([FX + 93, FY, FX + 93, FY + 127], fill=SEAM, width=2)
# col rond du t-shirt
d.arc([FX + 50, FY - 10, FX + 78, FY + 10], 0, 180, fill=BLUE_D, width=3)

# moto noire imprimee sur le t-shirt (silhouette simple)
mx, my = FX + 64, FY + 66
r = 9
d.ellipse([mx - 26 - r, my + 8 - r, mx - 26 + r, my + 8 + r], outline=MOTO, width=4)
d.ellipse([mx + 22 - r, my + 8 - r, mx + 22 + r, my + 8 + r], outline=MOTO, width=4)
d.polygon(
    [(mx - 22, my + 4), (mx - 12, my - 8), (mx + 4, my - 10), (mx + 12, my - 4),
     (mx + 22, my + 6), (mx + 8, my + 8), (mx - 8, my + 8)],
    fill=MOTO,
)
d.polygon([(mx - 14, my - 10), (mx - 2, my - 16), (mx + 8, my - 12), (mx - 4, my - 8)], fill=MOTO)  # reservoir et selle
d.line([mx + 12, my - 4, mx + 20, my - 18], fill=MOTO, width=3)  # fourche
d.line([mx + 16, my - 18, mx + 26, my - 20], fill=MOTO, width=3)  # guidon

# --- Bras (manches courtes noires, le reste transparent : on voit la peau) -
SLEEVE = 56  # sur 128 : la manche couvre le haut du bras jusqu'au coude
for ux in (217, 308):  # dessus des deux bras
    jacket_shade(ux, 289, 64, 64)
for fx in (19, 85, 151, 217, 308, 374, 440, 506):  # 4 faces de chaque bras
    jacket_shade(fx, 355, 64, SLEEVE)
    d.line([fx, 355 + SLEEVE - 3, fx + 63, 355 + SLEEVE - 3], fill=SEAM, width=2)  # ourlet

out = sys.argv[1] if len(sys.argv) > 1 else "shirt_baconhair.png"
img.save(out)
print(out)

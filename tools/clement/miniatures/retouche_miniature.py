# Retouche d'une miniature 1920 × 1080 (MOD-043, 2026-11-21) à partir de 2 captures Studio du même cadrage
# (brut.png, et matte.png où le perso et l'outil sont en néon vert pur, l'objet en néon magenta pur).
# On recadre en 16:9, on règle la lumière (+12 %), on pose le contour sombre de l'UI autour du perso,
# on renforce le halo qui existe en jeu et on écrit le texte du brief (Montserrat Black, blanc, contour #1B1B24).
# Lancer : py -I tools/clement/miniatures/retouche_miniature.py <dossier> "<TEXTE>" <coin> [x y largeur]
#   <coin> : haut-droite | haut-gauche | haut-centre ; x y largeur = zone 16:9 à garder (pixels de la capture).
import glob
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from retouche_icone import INK, chroma, grow, vignette  # noqa: E402

HALO = {"Epic": (168, 85, 247), "Legendary": (255, 194, 26), "Mythic": (255, 59, 92)}


def font(name, size):
    hits = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions", "*", "content", "fonts", name))
    return ImageFont.truetype(hits[0], size)


def title(img, text, corner, size=150, top=60):
    """Texte du brief : Montserrat Black blanc, contour #1B1B24 épais, ombre dure dessous ; jamais dans les
    216 px du bas. top : haut de la première ligne, en px."""
    f = font("Montserrat-Black.ttf", size)
    stroke = int(size * 0.1)
    lines = text.split("\n")
    d = ImageDraw.Draw(img)
    widths = [d.textlength(line, font=f) for line in lines]
    lh = int(size * 1.05)
    W, H = img.size
    margin = 70
    y = top
    for line, w in zip(lines, widths):
        if corner == "haut-droite":
            x = W - margin - w
        elif corner == "haut-gauche":
            x = margin
        else:
            x = (W - w) / 2
        d.text((x, y + size * 0.09), line, font=f, fill=INK, stroke_width=stroke, stroke_fill=INK)  # ombre dure
        d.text((x, y), line, font=f, fill=(255, 255, 255), stroke_width=stroke, stroke_fill=INK)
        y += lh
    assert y < H - 216, "le texte descend dans les 216 px du bas"
    return img


def main():
    folder, text, corner = sys.argv[1], sys.argv[2].replace("\\n", "\n"), sys.argv[3]
    rarity = os.environ.get("HALO", "Epic")
    brut = Image.open(os.path.join(folder, "brut.png")).convert("RGB")
    matte_path = os.path.join(folder, "matte.png")
    matte = Image.open(matte_path).convert("RGB") if os.path.exists(matte_path) else None
    W, H = brut.size
    if len(sys.argv) >= 7:
        x, y, w = (int(v) for v in sys.argv[4:7])
    else:
        w = min(W, int(H * 16 / 9))
        x, y = (W - w) // 2, (H - int(w * 9 / 16)) // 2
    h = int(w * 9 / 16)
    box = (x, y, x + w, y + h)
    brut = brut.crop(box).resize((1920, 1080), Image.LANCZOS)
    brut = brut.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    img = ImageEnhance.Contrast(brut).enhance(1.12)
    img = ImageEnhance.Color(img).enhance(1.12)
    img = Image.composite(Image.new("RGB", img.size, (12, 18, 40)), img, vignette(img.size, 0.45))
    if matte is not None:
        matte = matte.crop(box).resize((1920, 1080), Image.LANCZOS)
        hero, item = chroma(matte, "green"), chroma(matte, "magenta")
        # halo autour de l'objet seulement : l'objet garde ses couleurs (or de la Couronne)
        glow = item.filter(ImageFilter.GaussianBlur(60)).point(lambda v: min(255, int(v * 1.7)))
        glow = ImageChops.multiply(glow, ImageChops.invert(item)).point(lambda v: int(v * 0.6))
        img = Image.composite(Image.new("RGB", img.size, HALO[rarity]), img, glow)
        lit = ImageEnhance.Brightness(ImageEnhance.Color(brut).enhance(1.25)).enhance(1.1)
        img = Image.composite(lit, img, item)
        img = Image.composite(Image.new("RGB", img.size, INK), img, grow(hero, 22))  # contour de 10 à 12 px
        img = Image.composite(ImageEnhance.Contrast(brut).enhance(1.15), img, hero)
        img = Image.composite(Image.new("RGB", img.size, INK), img, ImageChops.subtract(grow(item, 16), item))
    img = title(img, text, corner)
    out = os.path.join(folder, os.environ.get("NOM", "THUMB.png"))
    img.save(out, optimize=True)
    img.resize((320, 180), Image.LANCZOS).save(out.replace(".png", "_controle_320x180.png"))
    print("ok", out, os.path.getsize(out) // 1024, "Ko")


if __name__ == "__main__":
    main()

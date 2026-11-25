# Planche de repérage : une image par plan, d'après une prise où les plans se suivent séparés par un noir
# (boucle T.still(nom) puis T._black(true) dans Studio, voir references/tournage-export.md, étape 5).
#   python -I planche_reperage.py <prise.mkv> <planche.jpg> <nom1,nom2,...> [colonnes=7] [roll=1]
# roll=1 : images tournées de 90° redressées (transpose=2) et recadrées en 9:16 (coupe du haut).
import os
import re
import subprocess
import sys
import tempfile

FF = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffmpeg.exe")
if not os.path.exists(FF):
    FF = "ffmpeg"

raw, out, names = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 7
roll = (sys.argv[5] if len(sys.argv) > 5 else "1") == "1"

log = subprocess.run([FF, "-hide_banner", "-i", raw, "-vf", "blackdetect=d=0.15:pic_th=0.90:pix_th=0.06", "-an", "-f", "null", "-"],
                     capture_output=True, text=True).stderr
blacks = [(float(a), float(b)) for a, b in re.findall(r"black_start:([0-9.]+) black_end:([0-9.]+)", log)]
# segments non noirs entre deux noirs
segs = [(blacks[i][1], blacks[i + 1][0]) for i in range(len(blacks) - 1) if blacks[i + 1][0] - blacks[i][1] > 0.3]
if len(segs) != len(names):
    print(f"attention : {len(segs)} images trouvées pour {len(names)} plans", file=sys.stderr)

tmp = tempfile.mkdtemp()
vf = "transpose=2,crop=min(iw\\,trunc(ih*9/16/2)*2):min(ih\\,trunc(iw*16/9/2)*2):(iw-ow)/2:ih-oh," if roll else ""
files = []
for i, (a, b) in enumerate(segs[: len(names)]):
    t = a + (b - a) * 0.6
    f = os.path.join(tmp, f"{i:02d}.png")
    label = f"{i + 1}. {names[i]}".replace(":", " ")
    subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{t:.3f}", "-i", raw, "-frames:v", "1", "-vf",
                    vf + "scale=270:-2,drawtext=fontfile='C\\:/Windows/Fonts/arialbd.ttf':text='" + label +
                    "':x=8:y=h-34:fontsize=17:fontcolor=white:box=1:boxcolor=black@0.65:boxborderw=6", f], check=True)
    files.append(f)

from PIL import Image

w, h = Image.open(files[0]).size
inputs = []
for f in files:
    inputs += ["-i", f]
n = len(files)
layout = "|".join(f"{(i % cols) * w}_{(i // cols) * h}" for i in range(n))
subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex",
                "".join(f"[{i}]" for i in range(n)) + f"xstack=inputs={n}:layout={layout}:fill=black", "-q:v", "3", out], check=True)
print(out, f"({n} images)")

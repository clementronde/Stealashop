# Découpe une prise de plusieurs plans tournés à la suite (boucle T.prepare / T.go dans Studio) en un fichier par plan.
#   python -I decoupe_lot.py <prise.mkv> <dossier> <nom1,nom2,...> [ralenti=2] [roll=1] [grade=2]
# Chaque plan est un passage non noir entre deux noirs (les noirs de T.prepare et de T.go se suivent entre deux plans).
# roll=1 : 9:16 (redressé, recadré, 1080 × 1920). roll=0 : 16:9 (1920 × 1080).
# grade : 0 aucun, 1 léger, 2 léger + vignette (choix validé par la DA et Clément le 2026-11-24).
import os
import re
import subprocess
import sys

FF = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffmpeg.exe")
if not os.path.exists(FF):
    FF = "ffmpeg"

raw, outdir, names = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
slow = float(sys.argv[4]) if len(sys.argv) > 4 else 2.0
roll = (sys.argv[5] if len(sys.argv) > 5 else "1") == "1"
grade = sys.argv[6] if len(sys.argv) > 6 else "2"
os.makedirs(outdir, exist_ok=True)

log = subprocess.run([FF, "-hide_banner", "-i", raw, "-vf", "blackdetect=d=0.08:pic_th=0.90:pix_th=0.06", "-an", "-f", "null", "-"],
                     capture_output=True, text=True).stderr
blacks = [(float(a), float(b)) for a, b in re.findall(r"black_start:([0-9.]+) black_end:([0-9.]+)", log)]
segs = [(blacks[i][1], blacks[i + 1][0]) for i in range(len(blacks) - 1) if blacks[i + 1][0] - blacks[i][1] > 0.8]
print(f"{len(segs)} plans trouvés pour {len(names)} noms")

look = {"0": "", "1": ",eq=saturation=1.14:contrast=1.05,unsharp=5:5:0.35",
        "2": ",eq=saturation=1.14:contrast=1.09,vignette=angle=PI/7,unsharp=5:5:0.35"}[grade]
# 16:9 : le viewport de Studio est plus large que 16:9 (1524 × 724 le 2026-11-24) : recadrage au centre avant l'agrandissement
geom = ("transpose=2,crop=min(iw\\,trunc(ih*9/16/2)*2):min(ih\\,trunc(iw*16/9/2)*2):(iw-ow)/2:ih-oh,scale=1080:1920:flags=lanczos" if roll
        else "crop=min(iw\\,trunc(ih*16/9/2)*2):ih,scale=1920:1080:flags=lanczos")
for (a, b), name in zip(segs, names):
    out = os.path.join(outdir, name + ".mp4")
    vf = f"trim=start={a:.3f}:end={b:.3f},setpts=(PTS-STARTPTS)/{slow},{geom},fps=30{look}"
    subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-i", raw, "-an", "-vf", vf,
                    "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out], check=True)
    subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-i", out, "-vf", "select=eq(n\\,40)", "-frames:v", "1",
                    os.path.join(outdir, name + ".jpg")])
    print(f"{name} : {(b - a) / slow:.2f} s")

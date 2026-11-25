# Pose les bruitages du jeu sur les plans découpés, d'après le journal des sons noté pendant le tournage (T.real.sfx).
#   python -I mix_sfx.py <journal.json> <dossier des plans> <banque de sons> [nom_du_plan=nom_du_fichier,…]
# journal.json : ce que rend T.real.sfxJson() dans Studio : { "nom_du_plan": [ {t, name, gain}, … ], … } ; t en
# secondes du plan (celles de la vidéo finale, une fois le ralenti rattrapé).
# Chaque plan <fichier>.mp4 du dossier reçoit une piste son (sans musique) ; l'original est remplacé.
# Les sons absents de la banque sont signalés et sautés. Mixage : sons posés à leur instant, sans baisser leur volume,
# limiteur à -1 dB, puis volume ramené vers -16 LUFS (réseaux sociaux).
import json
import os
import subprocess
import sys

FF = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffmpeg.exe")
FP = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffprobe.exe")
if not os.path.exists(FF):
    FF, FP = "ffmpeg", "ffprobe"

log = json.load(open(sys.argv[1], encoding="utf-8"))
clips, bank = sys.argv[2], sys.argv[3]
names = {}
if len(sys.argv) > 4:
    for pair in sys.argv[4].split(","):
        a, b = pair.split("=")
        names[a] = b

for shot, events in log.items():
    clip = os.path.join(clips, names.get(shot, shot) + ".mp4")
    if not os.path.exists(clip):
        continue
    dur = float(subprocess.run([FP, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", clip],
                               capture_output=True, text=True).stdout.strip() or 0)
    args, parts, missing = [], [], set()
    k = 0
    for ev in sorted(events, key=lambda e: e["t"]):
        f = os.path.join(bank, ev["name"] + ".wav")
        if not os.path.exists(f):
            missing.add(ev["name"])
            continue
        t = max(0.0, float(ev["t"]))
        if t >= dur:
            continue
        args += ["-i", f]
        k += 1
        gain = float(ev.get("gain", 1))
        parts.append(f"[{k}:a]adelay={int(t * 1000)}|{int(t * 1000)},volume={gain:.2f}[s{k}]")
    tmp = clip[:-4] + "_son.mp4"
    if k == 0:
        cmd = [FF, "-hide_banner", "-loglevel", "error", "-y", "-i", clip, "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
               "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-shortest", tmp]
    else:
        mix = "".join(f"[s{i}]" for i in range(1, k + 1))
        fc = ";".join(parts) + f";{mix}amix=inputs={k}:normalize=0:duration=longest,apad,atrim=duration={dur:.3f}," \
             "alimiter=limit=0.89,loudnorm=I=-16:TP=-1.5:LRA=11[a]"
        cmd = [FF, "-hide_banner", "-loglevel", "error", "-y", "-i", clip, *args, "-filter_complex", fc,
               "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", tmp]
    subprocess.run(cmd, check=True)
    os.replace(tmp, clip)
    print(f"{os.path.basename(clip)} : {k} sons" + (f" (absents : {', '.join(sorted(missing))})" if missing else ""))

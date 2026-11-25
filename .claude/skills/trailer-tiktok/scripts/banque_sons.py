# Banque de bruitages du jeu : découpe les prises son du Play (capture vidéo du MCP, qui enregistre le son du jeu)
# en un fichier <Nom>.wav par son.
#   python -I banque_sons.py <lots.txt> <dossier de sortie>
# lots.txt : une ligne par prise, « chemin.mp4|Dossier/Nom@début+durée;Dossier/Nom@début+durée;… », ce que rend
# _G.SB.play(k) dans le Play (références/tournage-export.md, « Banque de sons »). Les débuts sont comptés depuis le
# premier son du lot : le premier son entendu dans la prise (fin du premier silence) sert de repère de synchro.
import os
import re
import subprocess
import sys

FF = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Links", "ffmpeg.exe")
if not os.path.exists(FF):
    FF = "ffmpeg"

lots, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
done = 0
for line in open(lots, encoding="utf-8"):
    line = line.strip()
    if not line or "|" not in line:
        continue
    video, spec = line.split("|", 1)
    log = subprocess.run([FF, "-hide_banner", "-i", video, "-af", "silencedetect=n=-50dB:d=0.4", "-vn", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    ends = [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", log)]
    items = []
    for item in spec.split(";"):
        m = re.match(r"(.+?)@([0-9.]+)\+([0-9.]+)$", item.strip())
        if m:
            items.append((m.group(1).split("/")[-1], float(m.group(2)), float(m.group(3))))
    # Synchro : tous les débuts attendus du lot (impulsions aux instants donnés par le script) calés d'un coup sur la
    # courbe d'attaque de la piste (hausse d'énergie par fenêtre de 10 ms). Marche aussi quand la musique du jeu est
    # revenue sous les bruitages (pas de vrai silence) ou quand un son démarre en fondu.
    import numpy as np
    pcm = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-i", video, "-vn", "-ac", "1", "-ar", "16000", "-f", "s16le", "-"],
                         capture_output=True).stdout
    x = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    win = 160
    n = len(x) // win
    rms = np.sqrt(np.mean(x[: n * win].reshape(n, win) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms)
    onset = np.clip(np.diff(db, prepend=db[0]), 0, 30)
    onset = np.convolve(onset, np.ones(5), "same")
    best, sync = -1.0, ends[0] if ends else 1.0
    for k in range(85, min(170, n)):  # décalage cherché de 0,85 à 1,7 s (attente de 1 s du script + délai de la capture)
        score = 0.0
        for _, at, _ in items:
            i = k + int(round(at * 100))
            if i < n:
                score += onset[max(0, i - 2): i + 3].max()
        if score > best:
            best, sync = score, k / 100.0
    floor = float(np.percentile(db, 10))
    print(f"{os.path.basename(video)} : synchro {sync:.2f} s (silence : {ends[0] if ends else '-'}), fond {floor:.0f} dB")
    for name, at, d in items:
        start = sync + at - 0.02
        dur = d + 0.3
        out = os.path.join(outdir, name + ".wav")
        subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{max(0, start):.3f}", "-t", f"{dur:.3f}", "-i", video,
                        "-vn", "-af", "afade=t=out:st=" + f"{max(0, dur - 0.12):.3f}" + ":d=0.12", "-ar", "48000", "-ac", "2", out], check=True)
        done += 1
print(f"{done} sons écrits dans {outdir}")

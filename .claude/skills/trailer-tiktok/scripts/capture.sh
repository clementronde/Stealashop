#!/usr/bin/env bash
# Filme la vue 3D de Studio (Edit) à 60 i/s, sans le curseur.
#   capture.sh <sortie.mkv> <durée en s> <x> <y> <w> <h>
# x y w h : donnés par find_viewport.py. Lancer en arrière-plan juste AVANT T.go() :
# la prise commence pendant l'écran noir, qui sert de repère de synchro au montage.
# La fenêtre de Studio doit rester devant, non couverte, et personne ne touche à la vue pendant la prise.
set -euo pipefail
FF="${FFMPEG:-$LOCALAPPDATA/Microsoft/WinGet/Links/ffmpeg.exe}"
[ -x "$FF" ] || FF=ffmpeg
out="$1"; dur="$2"; x="$3"; y="$4"; w="$5"; h="$6"
"$FF" -hide_banner -loglevel error -y \
  -f gdigrab -framerate 60 -draw_mouse 0 -offset_x "$x" -offset_y "$y" -video_size "${w}x${h}" -i desktop \
  -t "$dur" -c:v libx264 -preset ultrafast -crf 10 -pix_fmt yuv420p "$out"
echo "$out"

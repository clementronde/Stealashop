#!/usr/bin/env bash
# D'une prise brute (capture.sh) à un plan 9:16 prêt pour TikTok.
#   montage_plan.sh <prise.mkv> <sortie.mp4> [ralenti=2] [coupe=haut|bas|centre] [grade=1]
# - Synchro : le plan va de la fin du premier écran noir (pré-roll de T.go) au début du dernier (post-roll).
# - Ralenti : la prise a été jouée <ralenti> fois plus lentement ; on l'accélère d'autant (plus d'images vraies).
# - Image : la caméra était tournée de 90° (roll) ; transpose=2 la remet debout, puis recadrage 9:16,
#   1080 × 1920 en lanczos, 30 i/s. coupe=haut enlève le haut de l'image (là où tombe le cube de vue de Studio).
# - grade=1 : saturation et contraste un peu poussés, léger renforcement de netteté (le style des références).
#   grade=2 : la même chose avec un peu plus de contraste et une vignette légère. Jamais plus fort : la DA veut
#   une image claire et saturée (StealAShop-Art/References/Style/Ciel_Couleurs), pas un jeu assombri.
#   grade=0 : aucun étalonnage.
# Écrit aussi <sortie>.jpg (l'image du milieu) pour la miniature et la relecture.
set -euo pipefail
FF="${FFMPEG:-$LOCALAPPDATA/Microsoft/WinGet/Links/ffmpeg.exe}"
[ -x "$FF" ] || FF=ffmpeg
raw="$1"; out="$2"; slow="${3:-2}"; cut="${4:-haut}"; grade="${5:-1}"

bd=$("$FF" -hide_banner -i "$raw" -vf "blackdetect=d=0.08:pic_th=0.90:pix_th=0.06" -an -f null - 2>&1 | grep -o "black_start:[0-9.]* black_end:[0-9.]*" || true)
[ -n "$bd" ] || { echo "pas d'écran noir dans la prise : synchro impossible" >&2; exit 1; }
start=$(echo "$bd" | head -1 | sed -E 's/.*black_end:([0-9.]+).*/\1/')
end=$(echo "$bd" | tail -1 | sed -E 's/black_start:([0-9.]+).*/\1/')
if [ "$(echo "$bd" | wc -l)" -lt 2 ]; then end=""; fi
echo "plan : de $start s à ${end:-la fin} s dans la prise"

case "$cut" in
  haut) cy="ih-oh" ;;
  bas) cy="0" ;;
  centre) cy="(ih-oh)/2" ;;
  *) echo "coupe = haut, bas ou centre" >&2; exit 1 ;;
esac
look=""
[ "$grade" = "1" ] && look=",eq=saturation=1.14:contrast=1.05,unsharp=5:5:0.35"
[ "$grade" = "2" ] && look=",eq=saturation=1.14:contrast=1.09,vignette=angle=PI/7,unsharp=5:5:0.35"
trim="trim=start=$start"
[ -n "$end" ] && trim="trim=start=$start:end=$end"

"$FF" -hide_banner -loglevel error -y -i "$raw" -an \
  -vf "$trim,setpts=(PTS-STARTPTS)/$slow,transpose=2,crop=min(iw\,trunc(ih*9/16/2)*2):min(ih\,trunc(iw*16/9/2)*2):(iw-ow)/2:$cy,scale=1080:1920:flags=lanczos,fps=30$look" \
  -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart "$out"
dur=$("$FF" -hide_banner -i "$out" 2>&1 | grep -o "Duration: [0-9:.]*" | cut -d' ' -f2 || true)
"$FF" -hide_banner -loglevel error -y -i "$out" -vf "select=eq(n\,45)" -frames:v 1 "${out%.*}.jpg" 2>/dev/null || true
echo "$out ($dur)"

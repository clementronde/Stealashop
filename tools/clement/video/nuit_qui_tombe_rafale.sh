#!/usr/bin/env bash
# Version « rafale » de « la nuit tombe » : 8 plans de 1,2 à 1,8 s qui suivent une même histoire
# (du jour à la nuit), montée avec ffmpeg.
#   bash nuit_qui_tombe_rafale.sh <dossier_brut> <sortie.mp4> [rafale|vigiles]
# <dossier_brut> : C_v2_30fps.mp4 (t 0 à 12,3), P1_30.mp4 et P2_30.mp4 (t 2,8 à 9,8 ; ralenti ×4 remis à
# vitesse), P3_30.mp4 (vigile suivi en temps réel, nuit). t = l'heure dans l'histoire, en s de vidéo.
# Profil « vigiles » : 5 plans, le mur monte côté couloir puis les vigiles de nuit et leurs lampes.
set -e
RAW="$1"; OUT="$2"; PROFILE="${3:-rafale}"
FF="$LOCALAPPDATA/Microsoft/WinGet/Links/ffmpeg.exe"
FONT="C\\:/Windows/Fonts/FuturaBold.ttf"
TMP="${TMPDIR:-/tmp}/nqt_rafale"; mkdir -p "$TMP"
[ -f "$TMP/stars.png" ] || "$FF" -loglevel error -y -f lavfi -i color=black:s=1080x1920 -frames:v 1 -vf "format=gray,geq=lum='if(gt(random(1)\,0.9988)\,255*(0.45+0.55*random(2))\,0)*clip((1000-Y)/600\,0\,1)',gblur=sigma=0.9,curves=all='0/0 0.12/0.85 1/1',format=rgb24" "$TMP/stars.png"

# seg <n> <source> <début dans la source> <durée> <t de l'histoire au début> <recadrage y>
seg() {
	local N="$1" SRC="$2" SS="$3" D="$4" T0="$5" CY="$6"
	local NI="clip((t+${T0}-3.0)/1.4\,0\,1)"
	local SA; SA=$(awk "BEGIN{v=(${T0}-3.4)/1.6; if(v<0)v=0; if(v>1)v=1; print v}") # étoiles à ce moment
	"$FF" -loglevel error -y -i "$RAW/$SRC" -loop 1 -i "$TMP/stars.png" -filter_complex "
	  [0:v]trim=start=${SS}:duration=${D},setpts=PTS-STARTPTS,transpose=2,crop=640:1138:0:${CY},
	       scale=1080:1920:flags=lanczos,unsharp=5:5:0.55:5:5:0,
	       hue=h='34*${NI}':s='1+0.25*${NI}',eq=gamma='1+0.28*${NI}':contrast='1+0.08*${NI}':eval=frame,
	       vignette=angle=PI/5,format=gbrp[b];
	  [1:v]trim=duration=${D},fps=30,format=gbrp[s];
	  [b][s]blend=all_mode=screen:all_opacity=${SA}:shortest=1,format=yuv420p,fps=30[v]" \
	  -map "[v]" -an -c:v libx264 -crf 14 -preset fast "$TMP/seg_$N.mp4"
}

if [ "$PROFILE" = vigiles ]; then
#   n  source          début  durée  t0    crop y
seg 1  P2_30.mp4       1.5    3.2    4.3   150   # le mur sort du sol, vu du couloir ; en haut à 3,0 s
seg 2  P3_30.mp4       2.0    1.4    12.0  330   # un vigile de nuit de près
seg 3  P1_30.mp4       5.2    1.6    8.0   100   # un vigile traverse la rue, faisceau
seg 4  P3_30.mp4       8.0    1.2    12.0  330   # encore le vigile, plus loin dans sa ronde
seg 5  C_v2_30fps.mp4  10.3   1.7    10.3  0     # fin large, étoile filante
SLAM=3.0; NSEG=5
else
#   n  source          début  durée  t0    crop y
seg 1  C_v2_30fps.mp4  1.2    1.6    1.2   0     # le jour doré file vers le coucher
seg 2  P1_30.mp4       0.0    1.8    2.8   100   # la rue au coucher, les premiers néons s'allument
seg 3  C_v2_30fps.mp4  4.6    1.4    4.6   0     # vue large : le mur commence à monter
seg 4  P2_30.mp4       3.2    1.6    6.0   150   # le mur vu du couloir arrive en haut (7,3 s)
seg 5  C_v2_30fps.mp4  7.6    1.2    7.6   0     # vue large, nuit violette
seg 6  P3_30.mp4       2.0    1.4    12.0  330   # un vigile de nuit de près, lampe torche
seg 7  P1_30.mp4       5.2    1.6    8.0   100   # un vigile traverse la rue, faisceau
seg 8  C_v2_30fps.mp4  10.3   1.7    10.3  0     # fin large, étoile filante, COMING SOON
# Le mur arrive en haut à 1,3 s dans le plan 4 : 1,6 + 1,8 + 1,4 + 1,3 = 6,1 s
SLAM=6.1; NSEG=8
fi
for i in $(seq 1 $NSEG); do echo "file '$TMP/seg_$i.mp4'"; done > "$TMP/list.txt"
"$FF" -loglevel error -y -f concat -safe 0 -i "$TMP/list.txt" -f lavfi -i "color=white:s=1080x1920:r=30" -filter_complex "
  [1:v]format=rgba,trim=duration=13,fade=in:st=$(awk "BEGIN{print ${SLAM}-0.04}"):d=0.04:alpha=1,fade=out:st=${SLAM}:d=0.3:alpha=1[fl];
  [0:v][fl]overlay=shortest=1,
  drawtext=fontfile='${FONT}':text='COMING SOON':fontsize='100+38*max(0\,1-(t-${SLAM})/0.18)':fontcolor=white:x=(w-text_w)/2:y=600-text_h/2:shadowcolor=black@0.6:shadowx=0:shadowy=7:enable='gte(t\,${SLAM})',
  format=yuv420p[v]" -map "[v]" -an -r 30 -c:v libx264 -preset medium -crf 19 -profile:v high -movflags +faststart "$OUT"
"$FF" -loglevel error -y -ss $(awk "BEGIN{print ${SLAM}+1.5}") -i "$OUT" -frames:v 1 -q:v 2 "${OUT%.mp4}.jpg"
ls -la "$OUT"

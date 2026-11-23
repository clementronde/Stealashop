#!/usr/bin/env bash
# Montage « la nuit tombe » : montage.sh <prise.mp4> <début_s> <sortie.mp4> [miniature.jpg] [t_miniature]
set -e
S="C:/Users/User/AppData/Local/Temp/claude/c832deb985144a86/ea528e5c-20e2-46ac-9027-e64f1d21e733/scratchpad"
FF="$LOCALAPPDATA/Microsoft/WinGet/Links/ffmpeg.exe"
IN="$1"; START="$2"; OUT="$3"; THUMB="$4"; TT="${5:-8.5}"
FONT="C\\:/Windows/Fonts/FuturaBold.ttf"

# Ciel étoilé (fixe, plus dense en haut, rien sous le tiers)
if [ ! -f "$S/stars.png" ]; then
"$FF" -loglevel error -y -f lavfi -i color=black:s=1080x1920 -frames:v 1 -vf "format=gray,geq=lum='if(gt(random(1)\,0.9988)\,255*(0.45+0.55*random(2))\,0)*clip((1000-Y)/600\,0\,1)',gblur=sigma=0.9,curves=all='0/0 0.12/0.85 1/1',format=rgb24" "$S/stars.png"
fi
# Étoile filante : traînée blanche, tête à droite
if [ ! -f "$S/streak.png" ]; then
"$FF" -loglevel error -y -f lavfi -i color=white@0:s=420x14,format=rgba -frames:v 1 -vf "geq=r=255:g=245:b=255:a='255*pow(X/W\,2.2)*exp(-pow(Y-7\,2)/(3+6*X/W))',rotate=a=0.42:ow=rotw(0.42):oh=roth(0.42):c=none" "$S/streak.png"
fi

NIGHT="clip((t-3.0)/1.4\,0\,1)"
TXT="C O M I N G   S O O N"

"$FF" -loglevel error -stats -y \
  -i "$IN" -loop 1 -i "$S/stars.png" -loop 1 -i "$S/streak.png" \
  -filter_complex "
  [0:v]trim=start=${START}:duration=12.3,setpts=PTS-STARTPTS,transpose=2,crop=640:1138:0:0,
       framerate=fps=30:interp_start=0:interp_end=255:scene=100,
       scale=1080:1920:flags=lanczos,unsharp=5:5:0.55:5:5:0,
       hue=h='34*${NIGHT}':s='1+0.25*${NIGHT}',
       eq=gamma='1+0.28*${NIGHT}':contrast='1+0.08*${NIGHT}':eval=frame,
       vignette=angle=PI/5,format=gbrp[base];
  [1:v]format=rgb24,trim=duration=12,setpts=PTS-STARTPTS,fps=30,fade=in:st=3.4:d=1.6,format=gbrp[stars];
  [base][stars]blend=all_mode=screen:shortest=1[sky];
  [2:v]format=rgba,fps=30,trim=duration=12,setpts=PTS-STARTPTS,split[s1][s2];
  [sky][s1]overlay=x='120+1100*(t-7.7)':y='170+470*(t-7.7)':enable='between(t,7.7,8.25)'[o1];
  [o1][s2]overlay=x='420+1000*(t-10.1)':y='60+430*(t-10.1)':enable='between(t,10.1,10.6)'[o2];
  [o2]drawtext=fontfile='${FONT}':text='${TXT}':fontsize=54:fontcolor=white:x=(w-text_w)/2:y=560:shadowcolor=black@0.55:shadowx=0:shadowy=5,
      trim=duration=12,format=yuv420p[v]" \
  -map "[v]" -an -r 30 -c:v libx264 -preset slow -crf 19 -profile:v high -pix_fmt yuv420p -movflags +faststart "$OUT"

if [ -n "$THUMB" ]; then
  "$FF" -loglevel error -y -ss "$TT" -i "$OUT" -frames:v 1 -q:v 2 "$THUMB"
fi
ls -la "$OUT" ${THUMB:+"$THUMB"}

# v2 (prise C au ralenti ×4, enregistrée en deux parties de 30 s, limite de video_capture) :
# assembler d'abord les deux parties, calées par PSNR sur la zone du mur (2,2 s de la 2e = 23,1 s de la 1re) :
#   ffmpeg -i C_slow.mp4 -i C_slow2.mp4 -filter_complex "[0:v]trim=start=1.5:end=23.1,setpts=PTS-STARTPTS[a];
#     [1:v]trim=start=2.2:end=29.9,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1:a=0,setpts=PTS/4,
#     framerate=fps=30:interp_start=0:interp_end=255:scene=100[v]" -map "[v]" -an -c:v libx264 -crf 12 C_v2_30fps.mp4
# puis : bash nuit_qui_tombe_montage.sh C_v2_30fps.mp4 0 nuit-qui-tombe_C_v2.mp4 miniature_C_v2.jpg 9.0

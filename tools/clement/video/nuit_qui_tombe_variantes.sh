#!/usr/bin/env bash
# Variantes de « la nuit tombe » (prise C v2), montées avec ffmpeg. Aucun nouveau tournage.
#   bash nuit_qui_tombe_variantes.sh <dossier_brut> <dossier_sortie> [nom ...]
# <dossier_brut> contient C_v2_30fps.mp4 (prise assemblée, ×4 accélérée, 30 i/s) et, pour la rampe,
# C_v2_real.mp4 (la même, à vitesse de tournage : 4 fois plus lente). Voir nuit_qui_tombe_montage.sh.
set -e
RAW="$1"; OUTDIR="$2"; shift 2
FF="$LOCALAPPDATA/Microsoft/WinGet/Links/ffmpeg.exe"
FONT="C\\:/Windows/Fonts/FuturaBold.ttf"
TMP="${TMPDIR:-/tmp}/nqt_var"; mkdir -p "$TMP"

# Ciel étoilé et étoile filante (comme le montage v1/v2)
[ -f "$TMP/stars.png" ] || "$FF" -loglevel error -y -f lavfi -i color=black:s=1080x1920 -frames:v 1 -vf "format=gray,geq=lum='if(gt(random(1)\,0.9988)\,255*(0.45+0.55*random(2))\,0)*clip((1000-Y)/600\,0\,1)',gblur=sigma=0.9,curves=all='0/0 0.12/0.85 1/1',format=rgb24" "$TMP/stars.png"
[ -f "$TMP/streak.png" ] || "$FF" -loglevel error -y -f lavfi -i color=white@0:s=420x14,format=rgba -frames:v 1 -vf "geq=r=255:g=245:b=255:a='255*pow(X/W\,2.2)*exp(-pow(Y-7\,2)/(3+6*X/W))',rotate=a=0.42:ow=rotw(0.42):oh=roth(0.42):c=none" "$TMP/streak.png"

# render <sortie> <entrée> <début> <durée> <hue> <t_nuit> <t_étoiles> <t_mur_en_haut> <étoile1> <étoile2> <texte> [miniature_t]
# texte : static (petit, tout le long) | slam (gros quand le mur arrive en haut, flash) | countdown (3-2-1 puis slam)
render() {
	local OUT="$1" IN="$2" START="$3" DUR="$4" HUE="$5" TN="$6" TS="$7" SLAM="$8" S1="$9" S2="${10}" TEXT="${11}" TT="${12:-}"
	local N="clip((t-${TN})/1.4\,0\,1)"
	local txt
	case "$TEXT" in
	static)
		txt="drawtext=fontfile='${FONT}':text='C O M I N G   S O O N':fontsize=54:fontcolor=white:x=(w-text_w)/2:y=560:shadowcolor=black@0.55:shadowx=0:shadowy=5"
		;;
	slam)
		txt="drawtext=fontfile='${FONT}':text='COMING SOON':fontsize='100+38*max(0\,1-(t-${SLAM})/0.18)':fontcolor=white:x=(w-text_w)/2:y=600-text_h/2:shadowcolor=black@0.6:shadowx=0:shadowy=7:enable='gte(t\,${SLAM})'"
		;;
	countdown)
		local C0; C0=$(awk "BEGIN{print ${SLAM}-3-3}") # 3 s de décompte, fini 3 s avant le haut du mur (= début de la montée)
		txt="drawtext=fontfile='${FONT}':text='NIGHT FALLS IN':fontsize=58:fontcolor=0xFFB347:x=(w-text_w)/2:y=470:shadowcolor=black@0.6:shadowx=0:shadowy=5:enable='between(t\,${C0}\,${C0}+3)',
drawtext=fontfile='${FONT}':text='%{eif\:3-floor(t-${C0})\:d}':fontsize='190+90*max(0\,1-mod(t-${C0}\,1)/0.15)':fontcolor=white:x=(w-text_w)/2:y=640-text_h/2:shadowcolor=black@0.6:shadowx=0:shadowy=8:enable='between(t\,${C0}\,${C0}+2.999)',
drawtext=fontfile='${FONT}':text='COMING SOON':fontsize='100+38*max(0\,1-(t-${SLAM})/0.18)':fontcolor=white:x=(w-text_w)/2:y=600-text_h/2:shadowcolor=black@0.6:shadowx=0:shadowy=7:enable='gte(t\,${SLAM})'"
		;;
	esac
	local flash=""
	if [ "$TEXT" != static ]; then
		flash="color=white:s=1080x1920:r=30,format=rgba,trim=duration=${DUR},fade=in:st=$(awk "BEGIN{print ${SLAM}-0.04}"):d=0.04:alpha=1,fade=out:st=${SLAM}:d=0.3:alpha=1[fl];[o2][fl]overlay=shortest=1[o3];"
	else
		flash="[o2]null[o3];"
	fi
	"$FF" -loglevel error -stats -y \
	  -i "$IN" -loop 1 -i "$TMP/stars.png" -loop 1 -i "$TMP/streak.png" \
	  -filter_complex "
	  [0:v]trim=start=${START}:duration=$(awk "BEGIN{print ${DUR}+0.2}"),setpts=PTS-STARTPTS,transpose=2,crop=640:1138:0:0,
	       scale=1080:1920:flags=lanczos,unsharp=5:5:0.55:5:5:0,
	       hue=h='${HUE}*${N}':s='1+0.25*${N}',
	       eq=gamma='1+0.28*${N}':contrast='1+0.08*${N}':eval=frame,
	       vignette=angle=PI/5,format=gbrp[base];
	  [1:v]format=rgb24,trim=duration=${DUR},setpts=PTS-STARTPTS,fps=30,fade=in:st=${TS}:d=1.6,format=gbrp[stars];
	  [base][stars]blend=all_mode=screen:shortest=1[sky];
	  [2:v]format=rgba,fps=30,trim=duration=${DUR},setpts=PTS-STARTPTS,split[s1][s2];
	  [sky][s1]overlay=x='120+1100*(t-${S1})':y='170+470*(t-${S1})':enable='between(t\,${S1}\,${S1}+0.55)'[o1];
	  [o1][s2]overlay=x='420+1000*(t-${S2})':y='60+430*(t-${S2})':enable='between(t\,${S2}\,${S2}+0.5)'[o2];
	  ${flash}
	  [o3]${txt},trim=duration=${DUR},format=yuv420p[v]" \
	  -map "[v]" -an -r 30 -c:v libx264 -preset medium -crf 19 -profile:v high -pix_fmt yuv420p -movflags +faststart "$OUT"
	if [ -n "$TT" ]; then "$FF" -loglevel error -y -ss "$TT" -i "$OUT" -frames:v 1 -q:v 2 "${OUT%.mp4}.jpg"; fi
}

V30="$RAW/C_v2_30fps.mp4"
for name in "$@"; do
	case "$name" in
	# 1. Texte qui claque quand le mur arrive en haut (flash blanc), au lieu du petit texte fixe
	slam) render "$OUTDIR/nqt_var1_slam.mp4" "$V30" 0 12 34 3.0 3.4 7.3 8.6 10.4 slam 9 ;;
	# 2. Décompte du jeu « NIGHT FALLS IN 3-2-1 » au coucher, puis le texte qui claque
	countdown) render "$OUTDIR/nqt_var2_decompte.mp4" "$V30" 0 12 34 3.0 3.4 7.3 8.6 10.4 countdown 9 ;;
	# 3. Rampe : vitesse normale, ralenti ×2 pendant la montée du mur, puis vitesse normale
	ramp)
		"$FF" -loglevel error -y -i "$RAW/C_v2_real.mp4" -filter_complex "
		  [0:v]trim=start=0:end=17.2,setpts=(PTS-STARTPTS)/4[a];
		  [0:v]trim=start=17.2:end=29.2,setpts=(PTS-STARTPTS)/2[b];
		  [0:v]trim=start=29.2,setpts=(PTS-STARTPTS)/4[c];
		  [a][b][c]concat=n=3:v=1:a=0,framerate=fps=30:interp_start=0:interp_end=255:scene=100[v]" -map "[v]" -an -c:v libx264 -crf 12 -preset fast "$TMP/ramp.mp4"
		render "$OUTDIR/nqt_var3_ralenti.mp4" "$TMP/ramp.mp4" 0 14 34 3.0 3.4 10.3 11.4 12.9 slam 11.5 ;;
	# 4. Nuit rose néon au lieu du violet
	magenta) render "$OUTDIR/nqt_var4_rose.mp4" "$V30" 0 12 68 3.0 3.4 7.3 8.6 10.4 static 9 ;;
	# 5. Version courte de 8 s, qui commence au coucher du soleil
	short) render "$OUTDIR/nqt_var5_courte.mp4" "$V30" 1.8 8 34 1.2 1.6 5.5 6.8 7.3 slam 7 ;;
	# 6. Boucle : la fin se fond dans la 1re image (le jour revient), pour une boucle sans coupure sur TikTok
	loop)
		render "$TMP/loop_base.mp4" "$V30" 0 12 34 3.0 3.4 7.3 8.6 10.4 static
		"$FF" -loglevel error -y -i "$TMP/loop_base.mp4" -filter_complex "
		  [0:v]split[m][f];[f]trim=end_frame=1,loop=loop=20:size=1,setpts=N/30/TB[first];
		  [m][first]xfade=transition=fade:duration=0.6:offset=11.4,format=yuv420p[v]" -map "[v]" -an -c:v libx264 -preset medium -crf 19 -movflags +faststart "$OUTDIR/nqt_var6_boucle.mp4"
		"$FF" -loglevel error -y -ss 9 -i "$OUTDIR/nqt_var6_boucle.mp4" -frames:v 1 -q:v 2 "$OUTDIR/nqt_var6_boucle.jpg" ;;
	esac
	echo "fait : $name"
done

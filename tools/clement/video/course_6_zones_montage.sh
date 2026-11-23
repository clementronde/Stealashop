#!/usr/bin/env bash
# Montage de « la course des 6 zones » (2026-11-21) : 3 prises au ralenti ×4 (R1, R2, F) → 1080 × 1920, 30 i/s.
#   bash course_6_zones_montage.sh <dossier des prises> <sortie.mp4>
# Prises de tools/clement/video/course_6_zones.luau (video_capture, 1744 × 752, caméra tournée de 90°).
# Calage (écart entre deux images consécutives, aux changements d'angle de caméra) :
#   R1 : top à 2,00 s ; changement d'angle à la porte 4 à 23,83 s (t = 5,46).
#   R2 : top à 1,51 s ; changement d'angle à la porte 4 à 2,07 s (t = 0,14) : raccord R1 → R2 sur ce changement.
#   F  : top à 1,42 s ; coupe de la rue vers l'allée à t = 1,6.
# Chiffres à l'écran, lus dans src/shared/Config le 2026-11-21 (valeurs V0, à relire avant de publier) :
#   villes = Zones.City (zone 1 : Theme « MINI MART ») ; rareté qui apparaît dans chaque zone = Rarities.ZoneOdds ;
#   « 1 in 238 » = ZoneOdds[6].Mythic = 0,42 % (un colis de rayon de zone 6 sur 238 est Mythique) ; couleurs = Rarities.Color.
set -e
IN="$1"; OUT="$2"
FF="$LOCALAPPDATA/Microsoft/WinGet/Links/ffmpeg.exe"
FONT="C\\:/Windows/Fonts/FuturaBold.ttf"
TMP="${TMPDIR:-/tmp}/c6z"; mkdir -p "$TMP"

# 1. Les 3 segments, accélérés ×4, redressés, recadrés en 9:16 et agrandis
seg() { # <prise> <début> <fin> <crop y> <sortie> [tenue finale en s]
	"$FF" -loglevel error -y -i "$IN/$1.mp4" -vf "trim=start=$2:end=$3,setpts=(PTS-STARTPTS)/4,framerate=fps=30:interp_start=0:interp_end=255:scene=100,transpose=2,crop=752:1337:0:$4,scale=1080:1920:flags=lanczos,unsharp=5:5:0.5:5:5:0,eq=saturation=1.12:contrast=1.04,format=yuv420p" -an -c:v libx264 -crf 14 -preset fast "$TMP/$5.mp4"
	if [ -n "$6" ]; then
		# image tenue : dans une passe à part (dans la chaîne ci-dessus, tpad n'ajoutait rien)
		"$FF" -loglevel error -y -i "$TMP/$5.mp4" -vf "tpad=stop_mode=clone:stop=$(awk "BEGIN{print int($6*30)}")" -an -c:v libx264 -crf 14 -preset fast "$TMP/$5_hold.mp4"
		mv -f "$TMP/$5_hold.mp4" "$TMP/$5.mp4"
	fi
}
seg R1 2.00 23.80 203 a        # T 0 → 5,45 : accroche drone, zones 1 à 3
seg R2 2.00 23.91 203 b        # T 5,45 → 10,91 : zones 4 à 6
seg F 1.42 17.42 40 c 1.6      # T 10,91 → 14,91, puis 1,6 s tenue : la Banque, le colis Mythique
printf "file '%s'\nfile '%s'\nfile '%s'\n" "$TMP/a.mp4" "$TMP/b.mp4" "$TMP/c.mp4" > "$TMP/list.txt"

# 2. Titres
G1=1.10; G2=2.23; G3=3.68; G4=5.45; G5=7.53; G6=9.95; REVEAL=12.51; END=14.6
pop() { echo "($2)*(1+0.35*max(0\,1-(t-$1)/0.15))"; } # taille qui claque à t = $1
zone() { # <début> <fin> <ligne 1> <rareté> <couleur> <taille>
	echo "drawtext=fontfile='$FONT':text='$3':fontsize='$(pop $1 62)':fontcolor=white:borderw=5:bordercolor=black@0.85:x=(w-text_w)/2:y=470-text_h/2:enable='between(t\,$1\,$2)',"
	echo "drawtext=fontfile='$FONT':text='$4':fontsize='$(pop $1 $6)':fontcolor=$5:borderw=8:bordercolor=black:shadowcolor=black@0.5:shadowx=0:shadowy=8:x=(w-text_w)/2:y=610-text_h/2:enable='between(t\,$1\,$2)',"
}
TXT="drawtext=fontfile='$FONT':text='HOW FAR':fontsize='$(pop 0.15 150)':fontcolor=white:borderw=8:bordercolor=black:x=(w-text_w)/2:y=480-text_h/2:enable='between(t\,0.15\,1.08)',
drawtext=fontfile='$FONT':text='CAN YOU GO?':fontsize='$(pop 0.35 118)':fontcolor=0xFFC21A:borderw=8:bordercolor=black:x=(w-text_w)/2:y=630-text_h/2:enable='between(t\,0.35\,1.08)',
$(zone $G1 $G2 'ZONE 1 - MINI MART' 'COMMON' 0xB0B7C3 104)
$(zone $G2 $G3 'ZONE 2 - LONDON' 'UNCOMMON' 0x2FE08F 112)
$(zone $G3 $G4 'ZONE 3 - TOKYO' 'RARE' 0x2F9BFF 124)
$(zone $G4 $G5 'ZONE 4 - LOS ANGELES' 'EPIC' 0xA855F7 134)
$(zone $G5 $G6 'ZONE 5 - PARIS' 'LEGENDARY' 0xFFC21A 128)
$(zone $G6 $REVEAL 'ZONE 6 - NEW YORK' 'MYTHIC' 0xFF3B5C 140)
drawtext=fontfile='$FONT':text='MYTHIC':fontsize='$(pop $REVEAL 190)':fontcolor=0xFF3B5C:borderw=10:bordercolor=black:shadowcolor=black@0.5:shadowx=0:shadowy=10:x=(w-text_w)/2:y=520-text_h/2:enable='gte(t\,$REVEAL)',
drawtext=fontfile='$FONT':text='1 in 238':fontsize='$(pop 13.0 96)':fontcolor=white:borderw=7:bordercolor=black:x=(w-text_w)/2:y=700-text_h/2:enable='gte(t\,13.0)',
drawtext=fontfile='$FONT':text='C O M I N G   S O O N':fontsize='$(pop $END 58)':fontcolor=white:borderw=5:bordercolor=black@0.85:x=(w-text_w)/2:y=1470-text_h/2:enable='gte(t\,$END)'" # sous le colis, au-dessus de la légende TikTok

# zoom-punch court à chaque porte et à la coupe sur le colis
Z="1"
for g in $G1 $G2 $G3 $G4 $G5 $G6 $REVEAL; do Z="$Z+0.06*gte(t\,$g)*exp(-(t-$g)/0.12)"; done

"$FF" -loglevel error -stats -y -f concat -safe 0 -i "$TMP/list.txt" -f lavfi -i "color=white:s=1080x1920:r=30" -filter_complex "
  [0:v]scale=w='trunc(1080*($Z)/2)*2':h='trunc(1920*($Z)/2)*2':eval=frame:flags=bicubic,crop=1080:1920:(in_w-1080)/2:(in_h-1920)/2,setsar=1,vignette=angle=PI/6[v0];
  [1:v]format=rgba,trim=duration=17,fade=in:st=$(awk "BEGIN{print $REVEAL-0.04}"):d=0.04:alpha=1,fade=out:st=$REVEAL:d=0.3:alpha=1[fl];
  [v0][fl]overlay=shortest=1,
  $TXT,
  format=yuv420p[v]" -map "[v]" -an -r 30 -c:v libx264 -preset slow -crf 23 -maxrate 9M -bufsize 18M -profile:v high -movflags +faststart "$OUT"
"$FF" -loglevel error -y -ss 13.6 -i "$OUT" -frames:v 1 -q:v 2 "${OUT%.mp4}.jpg"
ls -la "$OUT" "${OUT%.mp4}.jpg"

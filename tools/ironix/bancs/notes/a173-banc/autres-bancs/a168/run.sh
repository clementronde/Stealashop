#!/usr/bin/env bash
# a173 (2026-11-15, vague 53) : copie du banc a168 ; S1g et S1h acceptent le rappel vers la distance prévue (Chase.HoldRecallMax studs/s de plus ou de moins que la marche du serveur, jamais la vitesse mesurée du client). Lancée par lanceur.sh.
# Grand chef (2026-11-15) : arbre sans a168 (pas de MAX_RUSH_STEP dans GuardService) : le banc a153 tel quel, comme les autres copies.
_A168_R="${1:-/f/StealAShop}"
if ! grep -q "MAX_RUSH_STEP" "$_A168_R/src/server/Services/GuardService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a153-banc/run.sh" "$@"; fi
# a168 (2026-11-15) : copie d’a153, fins de ruée à 10 ± 0,5 et scénario frames (15, 30, 60 images/s).
# Banc hors Studio d'a153 (2026-11-14, vague 45) : nouvelle poursuite (Features.GuardChaseV2, Config/Chase).
#   store   zone 1 avec un minimum de 100K (Chase.Zone1SpeedRequired patché) : ruée jusqu'à 10 studs ; 100 % =
#           distance constante 10 s ; 99 % = baisse très lente ; 50 % = touché en moins de 2 s ; 200 % (Hold) =
#           constante ; trail ×2 avec 50K = constante ; vitesse lue sur le serveur (modificateur, client truqué)
#   gain    AboveRequired = "Gain" patché : à 200 %, le voleur s'éloigne
#   zone1   zone 1 sans minimum (V0) : ruée puis distance constante ; tutoriel (GetSpeedOverride) : l'ancienne règle
#   off     Features.GuardChaseV2 = false : l'ancienne vitesse (Zones[1].GuardSpeed), sans ruée
#   others  vigile de nuit et policier : ruée puis touché en moins de 2 s ; conducteur : rattrape de plus en plus vite
# Harnais : celui du banc a146 (a146-banc/autres-bancs/a36, overlap-ajout), ancien déroulé du braquage.
# Sur un arbre sans Config/Chase (avant a153) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]      VERBOSE=1 : écrit aussi les lignes ok et la sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B146="$H/../../../a146-banc"
X="$B146/autres-bancs/a36"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/shared/Config/Chase.luau" ]; then
	echo "banc a168 (poursuite à distance, fin de ruée anticipée) : SAUTÉ, a153 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-store gain zone1 off others frames}"
FILES="shared server/Services/AntiCheatService.luau server/Services/CarryService.luau server/Services/StatsService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/BatService.luau server/Services/GuardService.luau server/Services/PlotService.luau server/Services/ReturnBaseService.luau server/Services/TrainingService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/NightCycleService.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$X/stubs.luau" "$B146/overlap-ajout.luau" "$X/ext29.luau" "$X/ext36.luau"
		sources
		cat "$H/../../../a134-banc/levier-force.luau"
		cat "$H/../../../a134-banc/coups-en-rafale.luau"
		cat "$H/../../../a103-banc/ancien-deroule.luau"
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$X/setup.luau"
		cat "$H/commun.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    |^  mesure" | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a168 (poursuite à distance, fin de ruée anticipée) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

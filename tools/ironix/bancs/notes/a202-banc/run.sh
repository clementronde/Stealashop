#!/usr/bin/env bash
# Banc hors Studio d'a202 (vague 62, liaison L-198, Features.SingleBoxReveal) : un seul colis par braquage, tirage
# complet à l'ouverture, cinématique (RevealStarted, RevealEnded, RevealDone), objet porté d'office.
# Mise en place du banc a114 (a66-banc/autres-bancs/a30-banc, a114-banc/autres-bancs/a103-banc/head.luau), sans témoins ;
# Shared/ItemWeight remplacé par une doublure pilotée (pre.luau : IW.kg, IW.scale, IW.size, IW.class ; IW.lucks reçoit
# les chances passées à Roll), pour rester juste avec le vrai module d'a203.
#   reveal  un seul colis, tirage par la boîte seule, protection, chrono en pause, fin par RevealDone, par plafond,
#           sortie et mort, spam, plafond cassé, poids partout, 3 captures et retour au rayon
#   guard   vigile figé pour l'ouvreur puis reprise, batte refusée pendant la cinématique
#   oldflow Features.SingleBoxReveal = false : l'ouverture d'avant (montée de chance, objet sur le rayon, GrabItem)
# Arbre sans SingleBoxReveal (avant a202) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok et sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a202 (un seul colis, cinématique d'ouverture)"
if ! grep -q "SingleBoxReveal" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a202 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
BASE="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../a114-banc/autres-bancs/a103-banc/head.luau"
A134="$H/../a134-banc"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
SCENARIOS="${*:-reveal guard oldflow}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$BASE/stubs.luau"
		cat "$BASE/../stub-anticheat.luau"
		(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		cat "$A134/levier-force.luau"
		cat "$A134/coups-en-rafale.luau"
		cat "$H/pre.luau"
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$BASE/setup.luau"
		cat "$HEAD"
		cat "$H/head.luau"
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
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

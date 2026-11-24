#!/usr/bin/env bash
# Banc hors Studio d'a239 (vague 71, L-216 points 1, 4 et 7) :
#   night  annonce au serveur des colis Légendaire et plus qui apparaissent la nuit (Unbox.NightBox*), sur le harnais
#          du banc a229 (refill : a30 + a103, vrai StoreHeistService) avec un magasin de zone 4 et un de zone 5 ;
#   off    le même, Unbox.NightBoxAnnounce = false dans le fichier assemblé : aucune annonce ;
#   + lignes « MESURE » : temps calculé arrivée → premier objet exposé (tuto, zone 1, puissance de départ) et
#     tirage des mutations de matière (Mutations.Roll).
#   bash run.sh [racine du dépôt]
# Avant a239 (pas de NightBoxAnnounce dans Config/Unbox) : « SAUTÉ ».
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$H/.."
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a239 (annonce de nuit, premier braquage, mutations)"
if ! grep -q "NightBoxAnnounce" "$SRC/shared/Config/Unbox.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (avant a239) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
BASE="$S/a66-banc/autres-bancs/a30-banc"
{
	cat "$BASE/stubs.luau" "$BASE/../stub-anticheat.luau"
	sources "shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"
	cat "$BASE/setup.luau" "$S/a103-banc/head.luau" "$H/tests.a239.luau"
} > "$T/night.luau"
{
	printf 'ANNOUNCE_OFF = true\n'
	sed 's/NightBoxAnnounce = true,/NightBoxAnnounce = false,/' "$T/night.luau"
} > "$T/off.luau"
checks=0
fails=0
for name in night off; do
	out=$("$LUAU" "$(cygpath -w "$T/$name.luau")" 2>&1)
	printf '%s\n' "$out" | grep -E "MESURE|ÉCHEC|ERREUR" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -20
		echo "  $name : arrêté avant la fin"
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "$LABEL : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))

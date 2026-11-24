#!/usr/bin/env bash
# Banc hors Studio d'a147 (vague 41, 2026-11-14, audit de sécurité) : retour à la base coupé (Features.ReturnToBase),
# demandes refusées comptées (Net.OnViolation → TelemetryService, RemoteRefused), objet en double (DuplicateItem),
# mesure ZoneReached (champ facultatif ZonesReached du profil).
# Faux Roblox et mise en place : ceux de la copie a134 du banc a35 (télémétrie), lus sur place, plus ReturnBaseService.
# Arbre sans ZoneReached dans Config/Telemetry (avant la fusion d'a147) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]     VERBOSE=1 : écrit aussi les lignes ok et la sortie des modules
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
H="$ME/../a134-banc/autres-bancs/a35"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
if ! grep -q "ZoneReached" "$SRC/shared/Config/Telemetry.luau" 2>/dev/null; then
	echo "banc a147 : SAUTÉ (arbre sans ZoneReached) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-returnbase refusals duplicate zones off}"
FILES="shared server/Services/TelemetryService.luau server/Services/ShopService.luau server/Services/TutorialService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/ReturnBaseService.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext32.luau" "$H/ext35.luau"
		cat "$H/../../../a59-banc/autres-bancs/stub-anticheat.luau"
		sources
		cat "$H/../../levier-force.luau" "$H/../../coups-en-rafale.luau"
		if [ -f "$ME/pre.$name.luau" ]; then cat "$ME/pre.$name.luau"; fi
		cat "$H/setup.luau"
		cat "$ME/aides.luau"
		cat "$ME/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a147 (sécurité, ZoneReached) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

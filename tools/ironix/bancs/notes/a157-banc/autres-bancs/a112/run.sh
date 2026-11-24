#!/usr/bin/env bash
# Copie a157 (2026-11-14, vague 49 : aucun coup sur une vitrine PNJ depuis la zone safe) : le magasin PNJ du scénario
# était posé en x = -300, au bord de la zone safe du faux monde (600 × 600 centrée en 0) ; posé en x = -330, hors zone
# safe. Rien d autre ne change. Arbre sans Shared/SafeZone : le banc a112 d origine tourne tel quel.
if [ ! -f "${1:-/f/StealAShop}/src/shared/SafeZone.luau" ]; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a112-banc/run.sh" "$@"; fi
# Banc hors Studio d'a112 (2026-11-13, vague 33, Cantin) : vol entre joueurs sans chrono, alerte d'intrusion de la
# victime (casse, entrée, sortie, prise), chrono de casse PNJ inchangé. Faux Roblox, bouchons et mise en place lus
# dans la copie d'a37 du banc a32 (a37-banc/autres-bancs/a32-banc : vrais PvPService, TheftAlertService, BatService,
# WindowService, CarryService, TheftAlertController, BatController…). Bot : copie a112 du banc a96.
# Avant la fusion (pas de PvPService.GetIntruders) : « SAUTÉ » (0 vérification).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
O="$H/../../../a37-banc/autres-bancs/a32-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-intrusion}"
if ! grep -q "function PvPService.GetIntruders" "$SRC/server/Services/PvPService.luau" 2>/dev/null; then
	echo "banc a112 SAUTÉ : cet arbre n'a pas encore l'alerte d'intrusion"
	echo "banc a112 (vol sans chrono, alerte d'intrusion) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$O/stubs.luau" "$O/ext29.luau" "$O/ext32.luau"
		cat "$O/../stub-anticheat.luau"
		sources
		cat "$O/setup.luau"
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
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a112 (vol sans chrono, alerte d'intrusion) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

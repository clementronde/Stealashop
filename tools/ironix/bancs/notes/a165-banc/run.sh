#!/usr/bin/env bash
# Banc a165 (2026-11-14, vague 51, petits défauts vus au Play de fusion45).
#   steal : StealItem tolère le retard du réseau comme les rayons (StoreHeistService.ReachPad), sur la mise en place du
#           banc a29 (faux Roblox d'a36-banc/autres-bancs/a29-banc, copie a146 ; DepositToHand mis à false comme la copie a152).
#   + les copies a165 de a62 (chrono), a75 (arrivée en zone safe) et a149 (chrono de police, PoliceGradient) dans
#     autres-bancs, lancées par run-all-bancs.sh à la place des copies précédentes.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop) ; « SAUTÉ » sans a165 (pas de ReachPad exporté).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
O="$H/../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop}"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "StoreHeistService.ReachPad = reachPad" "$ROOT/src/server/Services/StoreHeistService.luau" 2>/dev/null; then
	echo "banc a165 (petits défauts de fusion45) SAUTÉ : vague 51 (a165) pas encore fusionnée : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -r "$ROOT/src" "$TMP/src"
sed -i 's/DepositToHand = true,/DepositToHand = false,/' "$TMP/src/shared/Config/HeldItem.luau"
SRC="$TMP/src"
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/PvPController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
checks=0; fails=0
for name in steal; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$O/stubs.luau" "$O/ext29.luau" "$O/../stub-anticheat.luau"
		sources
		cat "$O/setup.luau" "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		fails=$((fails + 1)); continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"; checks=$((checks + c)); fails=$((fails + f))
done
echo "banc a165 (petits défauts de fusion45) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))

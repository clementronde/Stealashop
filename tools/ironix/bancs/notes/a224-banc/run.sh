#!/usr/bin/env bash
# Banc hors Studio d'a224 (vague 67).
#   gain    gain du tapis « +2 » seul (et « +2ˣ³ »), Scale × la taille en vol et sur place, une ligne, PC et 844 × 390,
#           bulle « +32 », modèle de Clément intact (faux Roblox et montage d'a215 : a60, a190, a213, setup215)
#   still, stilloff, run, runoff : poursuite qui ralentit en arrivant (vrai GuardService, harnais a193 et a198 ; voir tests.chase.luau ; « off » = ApproachBrake 0, mesures d avant)
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-gain still stilloff run runoff}"
B="$(cd "$H/.." && pwd)"
A60="$B/a134-banc/autres-bancs/a60"
A190="$B/a205-banc/autres-bancs/a190"
A213="$B/a213-banc"
A215="$B/a215-banc"
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/HudMenuController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	if [ "$name" = "gain" ] && ! grep -q 'Scale = 1.5' "$SRC/shared/Config/Hud.luau"; then
		echo "  gain : SAUTÉ, a224 partie 1 pas encore fusionnée"
		continue
	fi
	if [ "$name" != "gain" ] && ! grep -q "ApproachBrake" "$SRC/shared/Config/Chase.luau"; then
		echo "  $name : SAUTÉ, a224 partie 2 pas encore fusionnée"
		continue
	fi
	if [ "$name" = "gain" ]; then
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A60/stubs.luau"
			sed -E -f "$A190/patches/quint.sed" "$A60/ext-motion.luau"
			cat "$A60/ext-a60.luau" "$B/a155-banc/ext-tohex.luau"
			sources
			cat "$A60/setup.luau" "$A60/setup-a60.luau" "$A190/setup190.luau" "$A213/setup213.luau" "$A215/setup215.luau" "$H/tests.gain.luau"
		} > "$OUT"
	else
		bash "$H/assemble-chase.sh" "$SRC" "$H/tests.chase.luau" "$name" > "$OUT"
	fi
	pattern="^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	if [ "$name" = "gain" ] || grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	else
		# comme a198-banc/run.sh : arbre sans Features.ShelfOpen, le harnais d'a193 passe par a172-banc/corrige.sh a168
		out=$(bash "$B/a172-banc/corrige.sh" a168 bash -c '"$HOME/.rokit/bin/luau.exe" "$1"' _ "$(cygpath -w "$OUT")" 2>&1)
	fi
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ|^  mesure" || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a224 (gain « +2 », poursuite qui ralentit) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

#!/usr/bin/env bash
# a294 (21/11) : scénario client de la caisse exclusive (RevealController + Reveal/Unbox sur un RevealStarted de la caisse),
# sur la mise en place du banc a287 (faux Roblox a68/a204, Reveal/Unbox monté, a259) ; copie de a287-banc/run.sh, lancée
# par run.sh sous f70c4-banc/corrige.sh a251 (Config/Reveal.Return.Time = 0).
#   bash client.sh [racine du dépôt]
LABEL="banc a294 client"
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-client}"
sources() {
	(cd "$SRC" && find $1 -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
A68="$N/a71-banc/autres-bancs/a68-banc"
A204="$N/a246-banc/autres-bancs/a204"
CLIENT_FILES="shared client/Controllers/UI client/Controllers/Reveal client/Controllers/RevealController.luau"
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A68/stubs.luau"
		sources "$CLIENT_FILES"
		cat "$A204/pre.client.luau"
		cat "$N/a71-banc/autres-bancs/a42-banc/setup.luau"
		cat "$A68/common.luau"
		cat "$A204/head.client.luau"
		cat "$N/a259-banc/head.client.luau"
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
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR${DUREES:+|^DUREES}" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

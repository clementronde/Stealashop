#!/usr/bin/env bash
# Banc hors Studio d'a287 (2026-11-21, Cantin en jeu : « on tombe tout de suite sur l'objet », « tous les objets ont une
# chance sur 112 ») : ouverture du colis, mise en place du banc a259 (faux Roblox a68/a204, Reveal/Unbox monté).
#   plan    Shared/UnboxPlan : plusieurs coups pour toutes les raretés (plus rare = plus de coups), cote qui monte d'un
#           bout à l'autre jusqu'à la vraie cote (OddsClimb), texte de BB_Reveal.Odds ; DUREES=1 : durées par rareté
#   client  RevealController + Reveal/Unbox : la cote vue image par image (monte à chaque coup, visible sur les
#           silhouettes, jamais vers le bas, finit sur la vraie), BB_Reveal.Odds et Income écrits (repli du code et
#           BB_Reveal de Clément aux textes d'exemple), cinématique d'avant sans plan
# Lancé sous f70c4-banc/corrige.sh (Config/Reveal.Return.Time = 0, comme les bancs a251 et a259). Arbre sans a287 :
# « SAUTÉ ». Les règles d'avant (interrupteur OddsClimb coupé) : banc a259 par a287-banc/autres-bancs/a259.
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : sortie complète
R0="${1:-/f/StealAShop}"
LABEL="banc a287 (ouverture du colis : coups, cote qui monte, BB_Reveal)"
if ! grep -q "OddsClimb = {" "${R0%/src}/src/shared/Config/Unbox.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ, a287 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
if [ -z "${A287_CORRIGE:-}" ]; then
	A287_CORRIGE=1 exec bash "$(cd "$(dirname "$0")/.." && pwd)/f70c4-banc/corrige.sh" a251 bash "$0" "$@"
fi
set -u
H="$(cd "$(dirname "$0")" && pwd)"
N="$(cd "$H/.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-plan client}"
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

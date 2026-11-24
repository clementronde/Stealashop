#!/usr/bin/env bash
# Banc a231, partie poids (vague 70) : un vieux profil passe par la vraie ItemWeight.Migrate (sources de src/shared,
# faux require du banc a203). Arbre sans WEIGHT_SIZES dans ItemWeight (avant a231) : SAUTÉ.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "WEIGHT_SIZES" "$SRC/shared/ItemWeight.luau" 2>/dev/null; then
	echo "banc a231 (vieux profils : taille d'avant retirée) : SAUTÉ, a231 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
OUT="$OUTDIR/run.poids.luau"
emit() { # emit <clé> <fichier>
	awk -v key="$1" '{ sub(/\r$/, ""); lines = lines $0 "\n" } END { printf "SOURCES[\"%s\"] = [==========[\n%s]==========]\n", key, lines }' "$2"
}
{
	echo "--!nocheck"
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	for f in "$SRC"/shared/Config/*.luau; do
		emit "Config/$(basename "$f" .luau)" "$f"
	done
	emit "ItemWeight" "$SRC/shared/ItemWeight.luau"
	emit "Text/DataService" "$SRC/server/Services/DataService.luau"
	cat "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error|^banc a231" || true; fi
if ! printf '%s\n' "$out" | grep -qE "^banc a231 .*: [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"; then
	printf '%s\n' "$out" | tail -15
	echo "banc a231 (vieux profils : taille d'avant retirée) : arrêté avant la fin : 1 vérification(s), 1 échec(s)"
	exit 1
fi
printf '%s\n' "$out" | grep -qE "^banc a231 .*, 0 échec\(s\)$"

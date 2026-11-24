#!/usr/bin/env bash
# Banc hors Studio d'a232 (vague 70, T-150, T-151) : le chiffre du gain reste en TextScaled (Roblox remet TextScaled à
# false quand TextWrapped = false) ; une ligne par espaces insécables ; vol et sur place, avec et sans exposant, avec et
# sans le modèle de Clément, PC et téléphone. Faux Roblox d'a215 (a60, a190, a213, setup215) + setup232.luau.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
B="$(cd "$H/.." && pwd)"
A60="$B/a134-banc/autres-bancs/a60"
A190="$B/a205-banc/autres-bancs/a190"
if ! grep -q "NBSP = utf8.char(0xA0)" "$SRC/client/Controllers/GainController.luau" 2>/dev/null; then
	echo "banc a232 (chiffre du gain en TextScaled) : SAUTÉ, a232 pas encore fusionné : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/HudMenuController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.a232.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A60/stubs.luau"
	sed -E -f "$A190/patches/quint.sed" "$A60/ext-motion.luau"
	cat "$A60/ext-a60.luau" "$B/a155-banc/ext-tohex.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$A60/setup.luau" "$A60/setup-a60.luau" "$A190/setup190.luau" "$B/a213-banc/setup213.luau" "$B/a215-banc/setup215.luau" "$H/setup232.luau" "$H/tests.a232.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a232 (chiffre du gain en TextScaled) : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ" || true; fi
c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
echo "banc a232 (chiffre du gain en TextScaled) : $c vérification(s), $f échec(s)"
exit $((f > 0))

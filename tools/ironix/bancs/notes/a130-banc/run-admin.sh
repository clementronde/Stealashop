#!/usr/bin/env bash
# Banc a130 (vague 39, 2026-11-14), partie admin : vrai AdminService et ses configs, faux Roblox et bouchons du banc
# a98 (harness.luau, lu sur place ; bouchon FortuneTowerService ajouté là-bas par a130). « SAUTÉ » sans l'événement Fortune.
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a130-admin"
if ! grep -q '"FortuneOpen"' "$SRC/shared/Config/Admin.luau" 2>/dev/null; then
	echo "$NAME : SAUTÉ, pas d'événement Fortune dans Config/Admin (a130 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
A98="$H/../a98-banc"
FILES="server/Services/AdminService.luau shared/AdminLists.luau shared/Format.luau shared/Types/Profile.luau shared/Net/Definitions.luau shared/Net/Validate.luau"
for m in Admin Balance Cosmetics DeepFreeze Features Items Monetization Mutations Potions Rarities SkillTree Unbox Upgrades Zones; do
	FILES="$FILES shared/Config/$m.luau"
done
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	printf '%s\n' $FILES | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	tr -d '\r' < "$A98/harness.luau"
	tr -d '\r' < "$H/tests.admin.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"

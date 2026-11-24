#!/usr/bin/env bash
# Banc hors Studio d'a98 (vague 29, 2026-11-12, L-108 point 4) : panel admin côté serveur. Vrais AdminService,
# Config/Admin, Shared/AdminLists, configs lues (Items, Rarities, Mutations, Cosmetics, Potions, Monetization,
# SkillTree, Upgrades, Unbox, Zones, Balance, Features), Format, Net/Definitions et Net/Validate (forme des appels) ;
# bouchons pour les autres services. Scénarios : contrat et listes, serveur en ligne (rang du groupe, refus d'un
# non-admin, StudioOnly, cible absente, téléport, remise à zéro), Studio (arguments bornés et Id revalidés, chaque
# commande). « SAUTÉ » sans AdminService.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok et la sortie du service
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a98"
if [ ! -f "$SRC/server/Services/AdminService.luau" ]; then
	echo "$NAME (panel admin) : SAUTÉ, pas d'AdminService (a98 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
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
	tr -d '\r' < "$H/harness.luau"
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
out=$("$LUAU" "$W" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^$NAME : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$line"
printf '%s' "$line" | grep -qE " 0 échec"

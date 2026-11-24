#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : commandes GiveStrength et SetBench retirées, potion Speed retirée, tapis à 19 achats ; faux arbre complété (Config/Tools).
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a98-banc/run.sh" "$@"; fi
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
for m in Admin Balance Cosmetics DeepFreeze Features Items Monetization Mutations Potions Rarities SkillTree Tools Unbox Upgrades Zones; do # a134 : Tools ajouté (Config/Zones le requiert depuis le rééquilibrage v2)
	FILES="$FILES shared/Config/$m.luau"
done
# Ajout pur d'a167 (2026-11-15, vague 51) : AdminService et AdminLists lisent Config/LiveEvents (événements live).
if [ -f "$SRC/shared/Config/LiveEvents.luau" ]; then FILES="$FILES shared/Config/LiveEvents.luau"; fi
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

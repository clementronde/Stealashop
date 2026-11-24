#!/usr/bin/env bash
# Banc hors Studio d a164 (2026-11-14, vague 51 : renaissance V0, RebirthService, Features.Rebirth coupé).
# Scénarios serveur (server.luau) : vrai RebirthService et vrais modules de Shared/Config (Rebirths, Items,
# Formulas…) sur un faux Roblox minimal et de faux services (lib.luau) : off (coupé hors Studio : rien ne bouge),
# studio (coupé en Studio : accroches neutres), refus (palier, porté, volé, sol, objet, argent : profil identique),
# reset (remise à zéro, 3 objets gardés, colis ouvert d office, objet remis), bonus (revenus, tapis, coffre-fort),
# atomic (aucun yield, service en erreur après coup : profil entier), test (attributs RebirthTest et
# RebirthTestLevel). L écran UI_Rebirth est dans la copie a164 du banc a39 (autres-bancs/a39-banc, ligne a39 du lanceur).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-off studio refus reset bonus atomic test}"
if [ ! -f "$SRC/server/Services/RebirthService.luau" ]; then
	echo "banc a164 (renaissance) : SAUTÉ, pas de RebirthService.luau dans $SRC (vague 51 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Sources assemblées une seule fois, en un seul awk (lancer un processus par fichier est lent ici).
COMMON="$TMP/common.luau"
(cd "$SRC" && awk '
	FNR == 1 { if (key != "") printf "]==========]\n"; key = FILENAME; sub(/\.luau$/, "", key); sub(/^shared\//, "", key); sub(/^server\/Services\//, "", key); printf "SOURCES[\"%s\"] = [==========[\n", key }
	{ sub(/\r$/, ""); print }
	END { printf "]==========]\n" }
' shared/Config/*.luau shared/Format.luau shared/Types/Profile.luau server/Services/RebirthService.luau) > "$COMMON"
tr -d '\r' < "$H/lib.luau" >> "$COMMON"
tr -d '\r' < "$H/server.luau" >> "$COMMON"
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		echo "--!nocheck"
		echo "SOURCES = {}"
		echo "SCENARIO = \"$name\""
		cat "$COMMON"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a164 (renaissance) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

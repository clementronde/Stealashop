#!/usr/bin/env bash
# Banc hors Studio d'a161 (2026-11-14, vague 50, L-165 points 4 et 5) : leaderboards et grand socle de l'objet le plus rare.
#   rarest : grand socle RarestDisplay (BB_RarestDisplay ou BB_Rarest sur LabelPoint, objet à sa taille réelle sur
#            ItemPoint, Mutation, Odds), ancien socle sans RarestDisplay ; chance formatée (Shared/ItemOdds) ; codage
#            des leaderboards (Config/Leaderboard). Harnais du banc a80 (faux Roblox d'a62 du banc a60 + ext-a75 +
#            ext-a80 + ext-a161, mise en place d'a80 lignes 1 à 101), vrai VfxController.
#   server : vrai LeaderboardService sur un faux minimal (server.luau) : meilleur revenu, profil sans le champ,
#            écritures et lectures de l'OrderedDataStore, classement, panneaux, Studio sans API, suffixe DEV.
# « SAUTÉ » sur un arbre sans LeaderboardService.
#   bash run.sh [racine du dépôt]      VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B60="$H/../a62-banc/autres-bancs/a60-banc"
A75="$H/../a75-banc"
A80="$H/../a80-banc"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
if [ ! -f "$SRC/server/Services/LeaderboardService.luau" ]; then
	echo "banc a161 (leaderboards, grand socle) : SAUTÉ, pas de LeaderboardService (a161 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau client/Controllers/VfxController.luau"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
count() {
	local name="$1" out="$2"
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	local line
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		return
	fi
	local c f
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
}
OUT="$TMP/run.rarest.luau"
{
	cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A75/ext-a75.luau" "$A80/ext-a80.luau" "$H/ext-a161.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	cat "$B60/setup.luau" "$B60/setup-a60.luau" "$A75/setup-a75.luau"
	sed -n '1,101p' "$A80/tests.vfx.luau"
	cat "$H/tests.rarest.luau"
} > "$OUT"
count rarest "$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)"
SV="$TMP/server.luau"
{
	for pair in "SOURCE:server/Services/LeaderboardService.luau" "LB_SOURCE:shared/Config/Leaderboard.luau" "FORMAT_SOURCE:shared/Format.luau" "FREEZE_SOURCE:shared/Config/DeepFreeze.luau"; do
		printf 'local %s = [==========[\n' "${pair%%:*}"; tr -d '\r' < "$SRC/${pair#*:}"; printf '\n]==========]\n'
	done
	cat "$H/server.luau"
} > "$SV"
count server "$("$LUAU" "$(cygpath -w "$SV")" 2>&1)"
echo "banc a161 (leaderboards, grand socle) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

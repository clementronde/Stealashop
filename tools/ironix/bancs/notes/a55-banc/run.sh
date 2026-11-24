#!/usr/bin/env bash
# Banc hors Studio d'a55 (vague 20, 2026-11-10, L-083 point 7) : récompense d'une zone complète de l'Index
# (prime unique Index.ZoneCash, +3 % de WalkSpeed par StatsService, +5 % de revenus gardés), une seule fois
# par zone (IndexRewards du profil, champ facultatif sans changement de version), payée au chargement si
# due, télémétrie IndexReward, Notify, index fermé.
# Faux Roblox, mise en place et bouchons : ceux de la copie d'a55 du banc a40 (autres-bancs/a40-banc :
# stubs, ext29, ext38, stub-anticheat, features, pre.on / pre.off, setup) avec ext51.luau et
# compat51.luau d'a53. Vrais : IndexService, StatsService, DataService, DisplayService, UnboxService… (FILES).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a55 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/autres-bancs/a40-banc"
A53="$H/../a53-banc"
ROOT="${1:-/f/StealAShop/agents/a55}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-reward rewardoff}"
if ! grep -q "IndexRewards" "$SRC/shared/Types/Profile.luau" 2>/dev/null; then
	echo "banc a55 (récompense de zone de l'Index) : SAUTÉ, pas d'IndexRewards dans Types/Profile (a55 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau client/Controllers/IndexController.luau client/Controllers/UI/Motion.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/stub-anticheat.luau" "$A53/ext51.luau"
		sources
		cat "$B/features.luau"
		if [ "$name" = "rewardoff" ]; then cat "$B/pre.off.luau"; else cat "$B/pre.on.luau"; fi
		cat "$B/setup.luau" "$A53/autres-bancs/compat51.luau"
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
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "^---|ÉCHEC|ERREUR|^    " | grep -vE "^--- " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a55 (récompense de zone de l'Index) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

#!/usr/bin/env bash
# Banc a430 (lot100, 24/11 ; L-331 et L-330 (3)) :
#   statue : vrai LeaderboardStatueService sur un faux Roblox (fake.luau) : avatar du n° 1 ramené à 18 studs, pieds sur
#            le socle, membres recalés sur leurs AnimationConstraint, Plastic, aucun script, statue dorée et « ??? »,
#            avatar illisible, copies de ServerStorage ignorées, crochet de test ;
#   scroll : vrai LeaderboardScrollController : copie de Board dans le PlayerGui (Adornee = Screen), recopie quand les
#            lignes changent (même défilement), panneau parti et revenu.
# Les scénarios des classements de la semaine (vols, récompense qui attend) sont dans autres-bancs/a409.
# « SAUTÉ » sans LeaderboardStatueService.
#   bash run.sh [racine du dépôt]
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a430 (statues du n° 1, défilement des panneaux)"
if [ ! -f "$SRC/server/Services/LeaderboardStatueService.luau" ]; then
	echo "$NAME : SAUTÉ, 0 vérification(s), 0 échec(s)"; exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total=0; failed=0
count() {
	local name="$1" out="$2" line c f
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror" || true
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then printf '%s\n' "$out" | tail -20; echo "  $name : arrêté avant la fin"; failed=$((failed + 1)); return; fi
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total=$((total + c)); failed=$((failed + f))
}
src() { printf 'local %s = [==========[\n' "$1"; tr -d '\r' < "$SRC/$2"; printf '\n]==========]\n'; }
for part in statue scroll; do
	OUT="$TMP/$part.luau"
	{
		src FREEZE_SOURCE shared/Config/DeepFreeze.luau
		src WCFG_SOURCE shared/Config/WeeklyLeaderboard.luau
		src LB_SOURCE shared/Config/Leaderboard.luau
		src STATUE_SOURCE server/Services/LeaderboardStatueService.luau
		src SCROLL_SOURCE client/Controllers/LeaderboardScrollController.luau
		tr -d '\r' < "$H/fake.luau"
		tr -d '\r' < "$H/tests.$part.luau"
		printf '\nprint(`{checks} vérification(s), {fails} échec(s)`)\n'
	} > "$OUT"
	count "$part" "$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)"
done
echo "$NAME : $total vérification(s), $failed échec(s)"
exit $((failed > 0))

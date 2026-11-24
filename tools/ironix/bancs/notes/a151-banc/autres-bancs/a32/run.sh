#!/usr/bin/env bash
# Copie a151 (2026-11-14, vague 43, Cantin : la porte d'une boutique se répare dès que l'intrus éjecté par le propriétaire
# était le dernier) : tests.defense.luau suit la règle nouvelle (porte réparée à l'éjection de Bob, Cy puis Dan la recassent
# avant de voler) ; les autres scénarios et fichiers sont ceux de la copie a134 (a134-banc/autres-bancs/a32), lus sur place.
# Arbre sans la vague 43 (pas de repairWhenEmpty dans PvPService) : la copie a134 tourne telle quelle.
if ! grep -q "repairWhenEmpty" "${1:-/f/StealAShop}/src/server/Services/PvPService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a134-banc/autres-bancs/a32/run.sh" "$@"; fi
#!/usr/bin/env bash
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : dans le faux arbre, la Force reste le levier de dégâts des scénarios et HitWindow garde son débit en rafale (a134-banc/levier-force.luau et coups-en-rafale.luau) ; rien d'autre ne change.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a128-banc/autres-bancs/a32-banc/run.sh" "$@"; fi
# Copie d'a128 (vague 39, 2026-11-14, Config/ShelfBoxes.MaxOutlines 25 → 20) de la copie a112 : tests.limit.luau lit la limite
# dans Config/ShelfBoxes.MaxOutlines (bonne avant et après la fusion) ; les autres scénarios sont ceux d'a112, copiés tels quels.
# Copie d'a112 (2026-11-13, vague 33, Cantin : alerte d'intrusion dès la casse ou l'entrée) : alert, screen, motion et limit
# suivent la règle nouvelle (alerte « BOB IS STEALING YOUR SHOP! » à la casse, la prise la remplace ; voleurs ratés sortis
# de la boutique). Sans PvPService.GetIntruders dans l'arbre, lance la copie d'a99 (bonne avant la fusion).
# Copie d'a99 (2026-11-12, décision de Cantin : défense par le propriétaire) : tests.defense.luau suit la règle
# nouvelle (le voleur frappé par le propriétaire est sorti et ne peut plus voler cette boutique pendant 60 s) :
# le coup « Thief » vise Cy (frappé par Bob), le coup « Box » et le coup dans le vide sont de Bob, le profil abîmé
# se joue avec Cy puis Dan. Faux Roblox, mise en place et autres scénarios lus dans la copie d'a37
# (a37-banc/autres-bancs/a32-banc). Sans PvP.KickRobCooldown dans l'arbre, lance la copie d'a37 (bonne avant
# et après la fusion).
#   bash run.sh [racine du dépôt] [scénarios…]
set -u
H151="$(cd "$(dirname "$0")" && pwd)"; H="$H151/../../../a134-banc/autres-bancs/a32" # a151 : chemins de la copie a134
O="$H/../../../a128-banc/../a37-banc/autres-bancs/a32-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-alert screen adrenaline defense limit motion}"
if ! grep -q "function PvPService.GetIntruders" "$SRC/server/Services/PvPService.luau" 2>/dev/null; then
	exec bash "$H/../../../a99-banc/autres-bancs/a32-banc/run.sh" "$ROOT" "$@"
fi
if ! grep -q "KickRobCooldown" "$SRC/shared/Config/PvP.luau" 2>/dev/null; then
	exec bash "$O/run.sh" "$ROOT" "$@"
fi
FILES="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$O/stubs.luau" "$O/ext29.luau" "$O/ext32.luau"
		cat "$O/../stub-anticheat.luau"
		sources
		cat "$H/../../levier-force.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../coups-en-rafale.luau" # a134 : faux arbre, voir ce fichier
		cat "$O/setup.luau"
		if [ -f "$H151/tests.$name.luau" ]; then cat "$H151/tests.$name.luau"; elif [ -f "$H/tests.$name.luau" ]; then cat "$H/tests.$name.luau"; else cat "$O/tests.$name.luau"; fi
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
echo "banc a32 (alerte de la victime) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

#!/usr/bin/env bash
# a267 (vague 80, 2026-11-20 : Features.Traps = true en DEV) : copie du banc a243 ; pre.luau pose Traps = false (off) ou true (on) dans le source assemblé, quel que soit le dépôt. Tests lus dans a243-banc.
# Banc hors Studio d'a243 (vague 72, L-218, L-216 point 11 : pièges de boutique, TrapService, TrapController,
# Config/Traps, tuile Traps de Config/SkillTree, Features.Traps). Harnais du banc a228 (faux Roblox et mise en place
# d'a29 lus sur place, lib84 et pre84 d'a84 copie a93), plus le vrai TrapService et le vrai TrapController.
#   off   Features.Traps = false (tel quel) : tuile « Soon », aucun piège même au niveau 4 (SkillTest)
#   on    Features.Traps = true (remplacé dans le source assemblé) : achat, pose, déclenchement, effets, recharge,
#         immunité, propriétaire épargné, portique (CameraSpotted), modèle de Clément nettoyé, retrait, client
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Arbre sans Config/Traps : « SAUTÉ » (0 vérification).
set -u
ME="$(cd "$(dirname "$0")" && pwd)"
H="$ME/../../../a243-banc"
A84="$H/../a93-banc/autres-bancs/a84-banc"
A29="$H/../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-off on}"
if [ ! -f "$SRC/shared/Config/Traps.luau" ]; then
	echo "banc a243 (pièges de boutique) : SAUTÉ, pas de Config/Traps dans $SRC (a243 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/ShopWallsService.luau server/Services/TrapService.luau client/Controllers/PvPController.luau client/Controllers/CameraAlertController.luau client/Controllers/TrapController.luau"
OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_c=0
total_f=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		echo "SCENARIO = \"$name\""
		# MarkerSounds (TrapController) demande Debris et SoundService, absents du faux Roblox : deux services muets.
		awk '{ print } /^\t\tAnimationClipProvider = AnimationClipProvider,$/ { print "\t\tDebris = { AddItem = function() end },"; print "\t\tSoundService = { Name = \"SoundService\" }," }' "$A29/stubs.luau"
		cat "$A29/ext29.luau"
		cat "$A29/../stub-anticheat.luau"
		(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
		cat "$ME/pre.luau"
		cat "$A84/pre84.luau"
		cat "$A29/setup.luau"
		cat "$A84/lib84.luau"
		cat "$H/tests.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
		echo "scénario $name : arrêté avant la fin"
		total_f=$((total_f + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total_c=$((total_c + c))
	total_f=$((total_f + f))
done
echo "banc a243 (pièges de boutique) : $total_c vérification(s), $total_f échec(s)"
exit $((total_f > 0))

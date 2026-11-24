#!/usr/bin/env bash
# Banc hors Studio d'a124 (vague 37, 2026-11-14, L-117 point 7) : le bot défend sa boutique et poursuit le voleur.
# Vrais : BotService, BatService, PvPService, TheftAlertService, StatsService, DisplayService, PlotService,
# WindowService, CarryService, Net, Config, Contract, Anim. Faux Roblox et mise en place du banc a32 (copie a37,
# lus sur place, comme a99 « owner »), complétés par ext124.luau (rig R15 simplifié, BotService dans l'arbre,
# animation SwingBat du joueur, son SwingBat_Impact, batte TOOL_Batte, déplacement simulé du bot par MoveTo).
# Scénarios : door (porte cassée : désancré, Run, suit le casseur sans le frapper dehors, frappe l'intrus,
# sortie et 60 s, retour et ré-ancrage), grab (objet pris : coup Defend, objet revenu, OnBotHit sans OnHit),
# flee (le voleur qui court le distance : abandon à la laisse, dépôt chez lui ; abandon au bout du temps),
# gentle (tuto : plus lent, une seule frappe). Le scénario tuto (TutorialService réel : IsGentle et bulle
# BotChase) tourne sur la mise en place du banc a121 (faux BotService complété par bot-extra.luau).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A32="$H/../a37-banc/autres-bancs/a32-banc"
A121="$H/../a121-banc"
A28="$A121/autres-bancs/a28-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-door grab flee gentle tuto}"
if ! grep -q "function BatService.BotSwing" "$SRC/server/Services/BatService.luau" 2>/dev/null; then
	echo "banc a124 SAUTÉ : cet arbre n'a pas encore la défense du bot"
	echo "banc a124 (le bot défend sa boutique) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES32="shared $(if [ -d "$SRC/client/Controllers/UI" ]; then echo client/Controllers/UI; fi) server/Services/TheftAlertService.luau server/Services/PvPService.luau server/Services/BatService.luau server/Services/BotService.luau server/Services/StatsService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/TheftAlertController.luau client/Controllers/BatController.luau client/Controllers/ShelfBoxController.luau"
FILES121="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"

sources() {
	(cd "$SRC" && find $1 -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		if [ "$name" = "tuto" ]; then
			cat "$A28/stubs.luau" "$A28/ext.luau" "$A28/ext28.luau"
			sources "$FILES121"
			awk -v bot="$A121/bot.luau" -v extra="$H/bot-extra.luau" '/^print\("== A\. Config\/Tutorial"\)/ { exit } /^-+ démarrage/ { while ((getline line < bot) > 0) print line; while ((getline line < extra) > 0) print line } { print }' "$A28/tests.luau"
			cat "$H/tests.tuto.luau"
		else
			cat "$A32/stubs.luau" "$A32/ext29.luau" "$A32/ext32.luau"
			cat "$A32/../stub-anticheat.luau"
			sources "$FILES32"
			cat "$A32/setup.luau"
			cat "$H/ext124.luau"
			cat "$H/tests.$name.luau"
		fi
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a124 (le bot défend sa boutique) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

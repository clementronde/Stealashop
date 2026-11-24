#!/usr/bin/env bash
# Banc hors Studio d'a126 (vague 38, 2026-11-14 ; liaison L-135 points 2 et 3, L-136 (a), L-085 point 4) :
#   tuto   : étape 14 « EscapeBot » (le bot défend) du vrai TutorialService, sur la mise en place du banc a121 (copie
#            a121 du banc a28 jusqu'à « == A. », faux BotService bot.luau) + bot-extra.luau d'a124, lus sur place ;
#   notify : un seul message à la fois dans UI_Toast pendant le tuto (vrai NotifyController), rien de changé hors tuto ;
#   admin  : AdminButton caché pendant le dialogue du receleur, remontré après (vrais PawnShopController et
#            AdminController), HudController sans ReturnBaseButton (aucun avertissement), contrat UI sans lui.
#   notify et admin tournent sur le faux Roblox client et la mise en place du banc a39 (copie a95), lus sur place,
#   complétés par post39.luau (contrôleurs ajoutés à l'arbre, écrans UI_Toast et UI_PawnShop).
# Sur un arbre sans EscapeBot dans Config/Tutorial (avant a126) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi toute la sortie
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-tuto notify admin}"
A121="$H/../a121-banc"
A28="$A121/autres-bancs/a28-banc"
A124="$H/../a124-banc"
A39="$H/../a95-banc/autres-bancs/a39-banc"
if ! grep -q "EscapeBot" "$SRC/shared/Config/Tutorial.luau" 2>/dev/null; then
	echo "banc a126 SAUTÉ : cet arbre n'a pas encore l'étape EscapeBot"
	echo "banc a126 (tuto un message à la fois, bouton BASE, AdminButton, le bot défend) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES121="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"
FILES39="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/NotifyController.luau client/Controllers/PawnShopController.luau client/Controllers/AdminController.luau server/Services/ContractChecker.luau"

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
			awk -v bot="$A121/bot.luau" -v extra="$A124/bot-extra.luau" '/^print\("== A\. Config\/Tutorial"\)/ { exit } /^-+ démarrage/ { while ((getline line < bot) > 0) print line; while ((getline line < extra) > 0) print line } { print }' "$A28/tests.luau"
		else
			cat "$A39/stubs.luau" "$A39/ext29.luau" "$A39/ext38.luau"
			sources "$FILES39"
			cat "$A39/setup.luau"
			cat "$H/post39.luau"
		fi
		cat "$H/tests.$name.luau"
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/^(scénario .* : )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a126 (tuto un message à la fois, bouton BASE, AdminButton, le bot défend) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

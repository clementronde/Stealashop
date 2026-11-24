#!/usr/bin/env bash
# Banc hors Studio d'a197 (vague 60, 2026-11-15, tuto : liste des tâches, flèche sur la cible exacte, Passer = une étape).
# Mise en place du banc a169 : faux Roblox et faux services de la copie a169 du banc a28 jusqu'à « == A. », faux
# BotService du banc a121 (bot.luau) et bot-extra.luau d'a124, puis tests.a197.luau : textes de la liste, Shared/TutorialTasks,
# progression envoyée par le serveur, flèche sur la cible exacte, Passer une étape à la fois, client (repli V0 et écran
# de Clément avec ou sans Tasks). Sur un arbre sans Tutorial.SkipOneStep (avant a197) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
A121="$H/../a121-banc"
A28="$H/../a169-banc/autres-bancs/a28"
A124="$H/../a124-banc"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "SkipOneStep" "$SRC/shared/Config/Tutorial.luau" 2>/dev/null; then
	echo "banc a197 (tuto : tâches, flèche, Passer) : SAUTÉ (arbre d'avant a197), 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A28/stubs.luau" "$A28/ext.luau" "$A28/ext28.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	awk -v bot="$A121/bot.luau" -v extra="$A124/bot-extra.luau" '/^print\("== A\. Config\/Tutorial"\)/ { exit } /^-+ démarrage/ { while ((getline line < bot) > 0) print line; while ((getline line < extra) > 0) print line } { print }' "$A28/tests.luau"
	cat "$H/tests.a197.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a197 (tuto : tâches, flèche, Passer) : arrêté avant la fin (erreur ci-dessus), 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|    " || true; fi
c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a197 (tuto : tâches, flèche, Passer) : $c vérification(s), $f échec(s)"
exit $((f > 0))

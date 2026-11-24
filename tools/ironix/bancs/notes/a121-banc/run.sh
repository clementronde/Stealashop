#!/usr/bin/env bash
# Banc hors Studio d'a121 (vague 36, 2026-11-13, L-085 point 4) : étapes 11 à 13 du tuto, le vol sur la boutique du bot
# (GoToBotShop, StealFromBot, BringStolenHome). Faux Roblox et faux services du banc a28 (copie a121 :
# autres-bancs/a28-banc, lus sur place : mise en place jusqu'à « == A. »), plus un faux BotService (bot.luau, inséré
# avant le démarrage de TutorialService), puis tests.a121.luau : bot présent, absent, parti pendant l'étape, objet
# perdu (13 → 12), profil fini, reprises (attente BotWait), Passer, vol d'un vrai joueur, bulles du client.
# Sur un arbre sans BotShopRadius dans Config/Tutorial (avant a121) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh            écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
A28="$H/autres-bancs/a28-banc"
LUAU="$HOME/.rokit/bin/luau.exe"
if ! grep -q "BotShopRadius" "$SRC/shared/Config/Tutorial.luau" 2>/dev/null; then
	echo "banc a121 (tuto, vol sur le bot) : SAUTÉ (arbre d'avant a121), 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/TutorialService.luau client/Controllers/TutorialController.luau"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	cat "$A28/stubs.luau" "$A28/ext.luau" "$A28/ext28.luau"
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
	awk -v bot="$H/bot.luau" '/^print\("== A\. Config\/Tutorial"\)/ { exit } /^-+ démarrage/ { while ((getline line < bot) > 0) print line } { print }' "$A28/tests.luau"
	cat "$H/tests.a121.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "banc a121 (tuto, vol sur le bot) : arrêté avant la fin (erreur ci-dessus), 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "banc a121 (tuto, vol sur le bot) : $c vérification(s), $f échec(s)"
exit $((f > 0))

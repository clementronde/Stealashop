#!/usr/bin/env bash
# Banc a312 (22/11, trouvés au Play f92) : arrêt de la roue au bon secteur dès le 2e tour d'une session, et définitions
# en double du contrat UI (avertissements comptés deux fois par le ContractChecker).
#   contrat : Contract/UI d'avant (ui-avant.luau = dedf84f) et du dépôt, chargés tels quels (tests.contrat.luau)
#   roue    : vrai WheelController sur le harnais du banc a266 (a268-banc/autres-bancs/a266/run.sh, scénario « on »),
#             avec tests.roue.luau à la place de ses tests
# Arbre sans a312 (UI_Index_v3 encore défini deux fois) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]        VERBOSE=1 : sortie complète
#   AVANT=1 bash run.sh [racine]         preuve : la partie roue sur une copie de l'arbre avec le WheelController
#                                        d'avant (wheel-avant.luau) et la partie contrat avec ui-avant.luau des deux
#                                        côtés ; les deux doivent échouer
set -u
H="$(cd "$(dirname "$0")" && pwd)"
S="$(cd "$H/../../.." && pwd)" # a314, puis lot96 : copie dans lot96-banc/autres-bancs/a312
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a312 (arrêt de la roue, contrat UI sans doublons)"
if [ "${AVANT:-}" != "1" ] && [ "$(grep -c 'Name = "UI_Index_v3"' "$REPO/src/shared/Contract/UI.luau")" -gt 1 ]; then
	echo "$LABEL : SAUTÉ, UI_Index_v3 encore défini deux fois (a312 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
total=0
fails=0
add() {
	local line c f
	line=$(printf '%s\n' "$1" | grep -E "$2" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$1" | tail -20
		echo "  $3 : arrêté avant la fin"
		fails=$((fails + 1))
		return
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	total=$((total + c))
	fails=$((fails + f))
	echo "  $3 : $c vérification(s), $f échec(s)"
}
show() {
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$1"; else printf '%s\n' "$1" | grep -E "ÉCHEC|ERREUR|error" | head -20; fi
}

# Partie contrat.
UI_NEW="$REPO/src/shared/Contract/UI.luau"
if [ "${AVANT:-}" = "1" ]; then UI_NEW="$H/ui-avant.luau"; fi
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
	printf 'UI_AVANT = [==========[\n%s\n]==========]\n' "$(tr -d '\r' < "$H/ui-avant.luau")"
	printf 'UI_APRES = [==========[\n%s\n]==========]\n' "$(tr -d '\r' < "$UI_NEW")"
	tr -d '\r' < "$H/tests.contrat.luau"
} > "$T/contrat.luau"
out=$("$LUAU" "$(cygpath -w "$T/contrat.luau")" 2>&1)
show "$out"
add "$out" "^banc a312 contrat : [0-9]+ vérification" "contrat"

# Partie roue.
ROOT="$REPO"
if [ "${AVANT:-}" = "1" ]; then
	mkdir -p "$T/avant"
	cp -r "$REPO/src" "$T/avant/src"
	cp "$H/wheel-avant.luau" "$T/avant/src/client/Controllers/WheelController.luau"
	ROOT="$T/avant"
fi
mkdir -p "$T/wheel"
cp "$H/tests.roue.luau" "$T/wheel/tests.luau"
sed -e "s|^ME=.*|ME=\"$T/wheel\"|" \
	-e "s|^H=.*|H=\"$S/a266-banc\"|" \
	-e 's/for scenario in on off; do/for scenario in on; do/' \
	-e 's/banc a266 (quêtes et roue)/banc a312 roue/g' \
	"$S/a268-banc/autres-bancs/a266/run.sh" > "$T/wheel/run.sh"
if [ "${VERBOSE:-}" = "1" ]; then
	sed -i 's/grep -E "ÉCHEC|ERREUR|error" | head -20/cat/' "$T/wheel/run.sh"
fi
out=$(bash "$T/wheel/run.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -v "^banc a312 roue : "
add "$out" "^banc a312 roue : [0-9]+ vérification" "roue"

echo "$LABEL : $total vérification(s), $fails échec(s)"
exit $((fails > 0))

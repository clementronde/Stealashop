#!/usr/bin/env bash
# Banc hors Studio d'a252 (L-244, L-245), vrai GuardService et Guard/CatchPickUp sur le harnais d'a193/a249/a250 :
#   ramasse      capture dans la rue avec CatchPickUp.Always : attribut CatchPickUp, objet en main (repli GrabFallback),
#                portage fini après le ramassage, au plus MaxAfterCatch s après la capture
#   ramasseoff   même chose, interrupteur Enabled coupé : l'objet repart dès la capture (avant)
#   rue          valeurs du dépôt (Always false) : dans la rue, rien ne change
#   nuit         CatchPickUp.NightSendHome (renvoi à la boutique après une capture de jour la nuit), hooks factices
#   nuitoff      DayCatchAtNightSendsHome coupé : jamais de renvoi
#   plan         CatchScene/Shot.Frame (cadrage de la caméra, pur)
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-ramasse ramasseoff rue nuit nuitoff plan}"
B="$(cd "$H/.." && pwd)"
if ! [ -f "$SRC/server/Services/Guard/CatchPickUp.luau" ] 2>/dev/null; then
	echo "banc a252 : SAUTÉ, a252 pas encore fusionné (0 vérification(s), 0 échec(s))"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	bash "$H/assemble.sh" "$SRC" "$H/tests.a252.luau" "$name" > "$OUT"
	pattern="^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	if grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	else
		out=$(bash "$B/a172-banc/corrige.sh" a168 bash -c '"$HOME/.rokit/bin/luau.exe" "$1"' _ "$(cygpath -w "$OUT")" 2>&1)
	fi
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ|^  mesure" || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a252 (capture qui se voit : ramassage, renvoi de nuit, plan large) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

#!/usr/bin/env bash
# Copie a135 (vague 40, 2026-11-14, Cantin : braquage de 6 s) : partie serveur sur la copie a135 du banc a103 (../a103-banc : Balance.Heist.Duration à 13 dans le faux arbre) ; partie client : celle d'a116, telle quelle. Tests inchangés.
# Banc hors Studio d'a116 (2026-11-13, Cantin : ouvrir un colis du rayon en RESTANT APPUYÉ sur E, maintien = GrabTime
# du type du colis, comme la prise de l'objet sorti).
#   serveur : scénario « hold » (tests.hold.luau) sur la mise en place du banc a103 (copie a116 : faux Roblox d'a30
#             copie a66, head.luau de autres-bancs/a103-banc) : un appel seul refusé, maintien trop court refusé,
#             maintien suffisant accepté pour chaque type, tolérance de 0,1 s, maintien remplacé.
#   client  : vrai HeistController sur le faux Roblox du banc a104 (copie a116), lignes 1 à 219 de son tests.luau
#             puis tests.client.luau : durée de l'invite « Open » par type, deux OpenShelfBox ; ShelfOpen = false : « Steal ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
LABEL="banc a116 (ouverture en restant appuyé)"
if ! grep -q '"OpenShelfBox"' "$SRC/shared/Net/Definitions.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas de remote OpenShelfBox) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
total=0; failed=0
# Serveur : le runner de la copie a116 du banc a103, avec son scénario remplacé par le nôtre.
S="$H/../a103-banc" # a135 : sa copie du banc a103 (chrono HEIST de 13 s dans le faux arbre)
TMPS="$(mktemp -d)"
trap 'rm -rf "$TMPS"' EXIT
cp "$S/run.sh" "$S/head.luau" "$TMPS/"
cp "$H/tests.hold.luau" "$TMPS/tests.hold.luau"
NOTESDIR="$(cd "$H/../../.." && pwd)"
sed -i "s#^H=.*#H=\"$TMPS\"#; s#^NOTES=.*#NOTES=\"$NOTESDIR\"#; s#^LABEL=.*#LABEL=\"$LABEL serveur\"#" "$TMPS/run.sh"
out=$(bash "$TMPS/run.sh" "$ROOT" hold 2>&1)
printf '%s\n' "$out" | grep -vE "vérification\(s\)" || true
line=$(printf '%s\n' "$out" | grep -E "serveur : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then failed=$((failed + 1)); else
	total=$((total + $(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/')))
	failed=$((failed + $(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')))
fi
# Client : le runner de la copie a116 du banc a104, avec un tests.luau composé.
C="$NOTESDIR/a116-banc/autres-bancs/a104-banc"
TMPC="$TMPS/client"
mkdir -p "$TMPC"
cp "$C/run.sh" "$C/harness.luau" "$TMPC/"
{ sed -n '1,219p' "$C/tests.luau"; cat "$H/tests.client.luau"; } > "$TMPC/tests.luau"
sed -i "s#^NAME=.*#NAME=\"banc a116 client\"#" "$TMPC/run.sh"
out=$(bash "$TMPC/run.sh" "$ROOT" 2>&1)
printf '%s\n' "$out" | grep -vE "vérification\(s\)" || true
line=$(printf '%s\n' "$out" | grep -E "client \(ouverture sur le rayon\) : [0-9]+ vérification" | tail -1)
if [ -z "$line" ]; then failed=$((failed + 1)); else
	total=$((total + $(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/')))
	failed=$((failed + $(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')))
fi
echo "$LABEL : $total vérification(s), $failed échec(s)"
exit $((failed > 0))

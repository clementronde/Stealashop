#!/usr/bin/env bash
# Banc hors Studio d'a317 (2026-11-23, L-299 et L-304 point 3, décisions de Cantin du 23/11) : sans faux Roblox.
#   Les fonctions pures sont lues dans les sources et exécutées (loadstring) avec les vrais Config/CashFlash et
#   Config/DisplayMotion : GainController.FlashRank et FlashGoal (rang de la tournée, transparence du voile),
#   ItemIdleController.FloatMotion (flottement, tour et sauts) ; le reste est contrôlé dans le texte des sources
#   (Cash_Collect plus joué sur une plaque mais encore pour l'encaissement automatique, compteur relâché au premier
#   billet, hauteur du flottement retirée du FitSize, BB_Item au sommet −0,15, Weight « 20 KG », UI_CashFlash une fois
#   au contrat).
# Écrit sans avoir été lancé (consigne du petit chef : la machine tournait la suite complète).
# Arbre sans Config/CashFlash (avant a317) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh           écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
NAME="banc a317 (jus de l'encaissement, objets exposés qui flottent)"
if [ ! -f "$SRC/shared/Config/CashFlash.luau" ]; then
	echo "$NAME : SAUTÉ, pas de Config/CashFlash : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared/Config/DeepFreeze.luau shared/Config/CashFlash.luau shared/Config/DisplayMotion.luau shared/Contract/UI.luau client/Controllers/GainController.luau client/Controllers/ItemIdleController.luau client/Controllers/DisplayController.luau client/Controllers/VfxController.luau client/Controllers/HudController.luau client/Controllers/MutationFxController.luau server/Services/DisplayService.luau"
sources() {
	for f in $FILES; do printf '%s\n' "$f"; done | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}"
OUT="$R1_D/run.a317.luau"
{
	if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; else echo "VERBOSE = false"; fi
	echo "SOURCES = {}"
	sources
	tr -d '\r' < "$H/tests.luau"
} > "$OUT"
out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then
	printf '%s\n' "$out" | tail -25
	echo "$NAME : arrêté avant la fin (erreur ci-dessus) : 0 vérification(s), 1 échec(s)"
	exit 1
fi
if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
echo "$NAME : $line"
f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
exit $((f > 0))

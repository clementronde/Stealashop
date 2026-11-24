#!/usr/bin/env bash
# Copie a114 (2026-11-13, Cantin : la prise d'un objet sorti fait sortir tout de suite un vigile ; à la fin du chrono,
# seuls les intrus encore dans le magasin ont un vigile) : tests.exit E2d (attend que le vigile de Bob sorte du
# magasin, règle a70), E2f (vigile à la prise), E2f2 (pas de second vigile à la fin du chrono), E2h.
# Banc hors Studio d'a110 (2026-11-13, vague 33, Cantin) : entrer dans un magasin PNJ puis en sortir sans
# rien, c'est fini pour ce joueur (StoreHeistService.stepEntries, Features.ShelfOpen = true).
# Vrais : StoreHeistService, CarryService, GuardService, BatService, WindowService, ToolService,
# StatsService, TruckEventService, Loader, Net, Config, Contract, Types. Faux Roblox, mise en place et
# outils : ceux du banc a103 (a30 copie a66 : stubs.luau, setup.luau ; a103-banc/head.luau), lus sur place.
#   exit     sorti sans objet : plus de chrono, aucun vigile, rideau local baissé jusqu'à la réouverture ;
#            sorti avec un objet : vigile ; resté dedans : vigile ; casseur resté dehors : chrono jusqu'à la fin
#   oldflow  Features.ShelfOpen = false (pre.oldflow.luau) : l'ancien déroulé ne change pas
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a110 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
# Avant la fusion d'a110 (pas de règle « sorti sans objet ») : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
BASE="$H/../../../a66-banc/autres-bancs/a30-banc"
HEAD="$H/../../../a103-banc/head.luau"
LABEL="banc a110 copie a114 (sortir du magasin sans rien)"
if ! grep -q 'sans objet : rideau baissé pour lui' "$SRC/server/Services/StoreHeistService.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas de règle « sorti sans objet » dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-exit oldflow}"
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$BASE/stubs.luau"
		cat "$BASE/../stub-anticheat.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$BASE/setup.luau"
		cat "$HEAD"
		cat "$H/tests.$name.luau"
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
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

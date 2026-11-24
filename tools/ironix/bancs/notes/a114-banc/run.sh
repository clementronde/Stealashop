#!/usr/bin/env bash
# Banc hors Studio d'a114 (2026-11-13, Cantin) : objet lié au vigile (GuardService, « Objet lié » ; StoreHeistService,
# fin du chrono). Vrais : StoreHeistService, CarryService, GuardService, BatService, WindowService, ToolService,
# StatsService, TruckEventService, Loader, Net, Config, Contract, Types. Faux Roblox, mise en place et outils : ceux
# du banc a103 copie a114 (a30 copie a66 : stubs.luau, setup.luau ; autres-bancs/a103-banc/head.luau), lus sur place.
#   link     ouvrir : rien ; prise : vigile lié ; capture → retour puis demi-tour à la reprise (joueur attrapé
#            compris) ; vigile effacé → un autre ressort ; 15 s → fin du lien ; rangé → fin ; fin du chrono : pas
#            de second vigile, vigile pour l'intrus resté dedans ; camion et objet volé : jamais liés
#   oldflow  Features.ShelfOpen = false (pre.oldflow.luau) : l'ancien déroulé ne change pas
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
# Avant a114 (pas de GuardService.GetLinkedGuard) : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
BASE="$H/../a66-banc/autres-bancs/a30-banc"
HEAD="$H/autres-bancs/a103-banc/head.luau"
LABEL="banc a114 (objet lié au vigile)"
if ! grep -q 'GetLinkedGuard' "$SRC/server/Services/GuardService.luau" 2>/dev/null; then
	echo "$LABEL : SAUTÉ (pas d'objet lié dans cet arbre) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
SCENARIOS="${*:-link oldflow}"
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "$LABEL : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

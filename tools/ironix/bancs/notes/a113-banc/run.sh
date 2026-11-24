#!/usr/bin/env bash
# Banc hors Studio d'a113 (vague 33, Cantin 2026-11-13) : lâcher ce qu'on porte (remote DropCarried, DropService,
# DropController, CarryService.Drop(player, nil, "Released"), GuardService.IsStunned).
# Repose sur le banc de la batte (copie active : a66-banc/autres-bancs/a30-banc, lue sur place, rien de copié) :
# son faux Roblox (stubs.luau, plus un faux ContextActionService ajouté à la volée : cas.luau), ses bouchons, son
# setup, l'ancien déroulé (a103-banc/ancien-deroule.luau), puis tests.<scénario>.luau d'ici.
# Sur un arbre sans DropService (avant a113) : « SAUTÉ ».
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop ; scénarios : server client)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
A30="$H/../a66-banc/autres-bancs/a30-banc"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-server client}"
if [ ! -f "$SRC/server/Services/DropService.luau" ]; then
	echo "banc a113 (lâcher) : SAUTÉ (arbre d'avant a113), 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/BatService.luau server/Services/CarryService.luau server/Services/GuardService.luau server/Services/StoreHeistService.luau server/Services/WindowService.luau server/Services/ToolService.luau server/Services/StatsService.luau server/Services/TruckEventService.luau server/Services/DropService.luau client/Controllers/BatController.luau client/Controllers/HitController.luau client/Controllers/TruckController.luau client/Controllers/DropController.luau"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/cas.luau"
		sed 's/^\(\t*\)ContentProvider = ContentProvider,$/&\n\1ContextActionService = CAS_STUB, -- a113/' "$A30/stubs.luau"
		cat "$A30/../stub-anticheat.luau"
		sources
		cat "$H/../a103-banc/ancien-deroule.luau"
		cat "$A30/setup.luau"
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
	if [ "${VERBOSE:-}" = "1" ]; then printf '%s\n' "$out"; else printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR" || true; fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a113 (lâcher) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

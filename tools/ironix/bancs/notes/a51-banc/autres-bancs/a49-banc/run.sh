#!/usr/bin/env bash
# Copie d'a51 (2026-11-09, L-089) : colis rangé dans l'inventaire puis posé au sol (compat51.luau après le setup d'a46, ext51.luau) ; l'objet ouvert va dans l'inventaire, posé ensuite sur son présentoir (PlaceItem) pour garder les contrôles de l'objet exposé ; colis de l'ancienne file : dans l'inventaire, posé puis ouvert ; version attendue v7 ; client : invite « Open » sur le FloorBox, ligne « [Unbox] colis <uid> : … ». Scénarios heist, carry, pvp, truck : ceux d'a49-banc (inchangés).
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance le banc d'origine (a49-banc) : bon avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a49-banc/run.sh" "$@"; fi
# Banc hors Studio d'a49 (DEV-131, liaison L-084 point 3) : mutations en deux familles cumulables
# (taille, effet). Config/Mutations (valeurs de Clément, tirage), suivi du colis porté jusqu'à l'objet
# (Boxes, Items, sans changer la version du profil), revenu multiplié (présentoir, BB_Item, GetExposed,
# écran d'ouverture), échelle du modèle exposé (Model:ScaleTo), attributs MutationSize / MutationEffect.
# Scénarios config, stand et client : faux Roblox et mise en place d'a46 (../a46-banc : stubs, ext29,
# ext38, ext46, stub-anticheat, features, pre.on, setup), plus ext49.luau (Model:ScaleTo). Scénarios
# heist (tirage à la mise en rayon, accroche du tuto), carry (étiquettes BB_Box / BB_Carry), pvp (vol) et
# truck (colis du camion) : dossiers heist, carry, pvp et truck (faux Roblox des bancs a17-heist (copie
# d'a49 dans autres-bancs), a17-carry (copie d'a22), a29 (copie d'a36) et a27 (copie d'a46)).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a49)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../../../a46-banc"
ROOT="${1:-/f/StealAShop/agents/a49}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-config stand client heist carry pvp truck}"
if [ ! -f "$SRC/shared/Config/Mutations.luau" ]; then
	echo "banc a49 (mutations) : SAUTÉ, pas de Config/Mutations (DEV-131 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/ContractChecker.luau client/Controllers/UnboxController.luau client/Controllers/Unbox"
sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	if [ -f "$H/$name/run.sh" ]; then
		out=$(bash "$H/$name/run.sh" "$ROOT" 2>&1)
	else
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$B/stubs.luau" "$B/ext29.luau" "$B/ext38.luau" "$B/ext46.luau" "$B/stub-anticheat.luau" "$H/ext49.luau" "$H/../../ext51.luau"
		sources
		cat "$B/features.luau" "$B/pre.on.luau" "$B/setup.luau" "$H/../compat51.luau"
		if [ "$name" = "client" ]; then
			# buildUnbox (écran UI_Unbox) du scénario client d'a46, sans ses vérifications.
			awk '/^advance\(1000\)/ { exit } { print }' "$B/tests.client.luau"
		fi
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	fi
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
echo "banc a49 (mutations) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

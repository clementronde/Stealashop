#!/usr/bin/env bash
# Banc hors Studio d'a51 (L-089, vague 18, 2026-11-09) : le colis porté entre dans l'inventaire à l'entrée
# de la zone safe (un Tool de la barre, InventoryService), le joueur le pose où il veut au sol de SA
# boutique (PlaceBox(boxUid, point)), il s'ouvre là (OpenBox(boxUid)), l'objet gagné va dans l'inventaire
# (Tool), se pose sur un présentoir libre (PlaceItem) ou par Equip Best ; profil v7 et migration v6 → v7 ;
# non-duplication (double clic, mort, départ, vol).
# Faux Roblox d'a46 (stubs.luau d'a36, ext29, ext38, ext46), complété par ext51.luau (GetPartBoundsInBox,
# OverlapParams, GetMouse, caméra) ; mise en place setup.luau (zone safe, boutique 2 tournée de 90°).
# Vrais : InventoryService, DataService (faux ProfileStore d'ext38), DisplayService, PlotService,
# UnboxService, MonetizationService, IndexService, TrainingService, StatsService, ToolService, ShopService,
# UnboxController, InventoryController et les modules Unbox, Loader, Net, Config, Contract, Format, Types.
# Bouchons : TelemetryService, CarryService, AntiCheatService, TutorialService (accroche), PvPService.
# Chaque scénario tourne dans son propre luau (état neuf).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a51 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a51}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-stow place open inventory equipbest migration client money}"
# Arbre d'avant la fusion de L-089 (un autre agent lance run-all-bancs.sh sur son worktree) : rien à
# tester, on le dit et on passe.
if [ ! -f "$SRC/server/Services/InventoryService.luau" ]; then
	echo "banc a51 (colis dans l'inventaire, au sol) : SAUTÉ, pas d'InventoryService (L-089 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/InventoryService.luau server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/UnboxController.luau client/Controllers/InventoryController.luau client/Controllers/Unbox"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/ext46.luau" "$H/stub-anticheat.luau" "$H/ext51.luau"
		sources
		cat "$H/features.luau" "$H/pre.on.luau" "$H/setup.luau" "$H/tests.$name.luau"
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
echo "banc a51 (colis dans l'inventaire, au sol) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

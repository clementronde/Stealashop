#!/usr/bin/env bash
# 2026-11-08 (Claude principal) : RobuxShopController passe par UI/Motion (DEV-052) → module UI/Motion monté (FILES et setup.luau) ; le TweenService du faux Roblox finit les tweens tout de suite.
# Banc hors Studio d'a38 (DEV-100) : la boutique Robux (MonetizationService, Config/Monetization,
# accroches de DisplayService, TrainingService et UnboxService, DataService v3 et SaveAsync,
# RobuxShopController).
# Vrais : MonetizationService, DataService (faux ProfileStore d'ext38 : sauvegarde confirmée par
# OnAfterSave), DisplayService, PlotService, TrainingService, UnboxService, StatsService, ToolService,
# ShopService, RobuxShopController, Loader, Net, Config, Contract, Format, Types. Bouchons :
# TelemetryService, CarryService, AntiCheatService, TutorialService (son accroche de GetOpenDelay).
# Faux Roblox : celui d'a36 (stubs.luau), complété par ext29.luau (a29) et ext38.luau (énumérations,
# MarketplaceService, ProfileStore). Chaque scénario tourne dans son propre luau (état neuf) :
# pre.on.luau (boutique ouverte, Ids du banc) sauf pour « off », setup.luau, puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a38 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a38}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-off receipts passes effects offers studio prod client}"
# Arbre d'avant la fusion de DEV-100 (un autre agent lance run-all-bancs.sh sur son worktree) :
# rien à tester, on le dit et on passe.
if [ ! -f "$SRC/server/Services/MonetizationService.luau" ]; then
	echo "banc a38 (boutique Robux) : SAUTÉ, pas de MonetizationService.luau dans $SRC (DEV-100 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau client/Controllers/RobuxShopController.luau client/Controllers/UI/Motion.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/stub-anticheat.luau"
		sources
		if [ "$name" != "off" ]; then cat "$H/pre.on.luau"; fi
		cat "$H/setup.luau"
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
echo "banc a38 (boutique Robux) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

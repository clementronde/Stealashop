#!/usr/bin/env bash
# Copie d'a65 (vague 22, 2026-11-11, L-093) : banc sans invite (tests.effects.luau, ×2 Entraînement : on entre dans la
# zone du banc). Sur un arbre sans UseZone dans TrainingService, relance la copie d'a53 : bonne avant et après la fusion.
if ! grep -qE "USE_ZONE|TrainingZone" "${1:-/f/StealAShop}/src/server/Services/TrainingService.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a53-banc/autres-bancs/a38-banc/run.sh" "$@"; fi
# Copie d'a53 (2026-11-09, DEV-101) : profil v8 (receipts) ; boutique coupée, le boost ×2 argent des récompenses reste branché quand l'arbre a Config/Rewards (off : boost du profil repris, AddCashBoost accepté) ; bonne avant et après la fusion.
# Copie d'a51 (2026-11-09, L-089) : les colis rentrent dans l'inventaire puis se posent au sol (compat51.luau après setup.luau : placeBox, slotBox, floorBoxN, openPlaced ; ext51.luau pour GetPartBoundsInBox) ; « Ouvrir maintenant » et « Ouverture rapide » visent les colis posés par uid ; version attendue v7 (receipts).
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a48-banc/autres-bancs/a38-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a48-banc/autres-bancs/a38-banc/run.sh" "$@"; fi
# Copie d'a48 (2026-11-08, DEV-102) : profil v6 (Offline, gains hors ligne) → version attendue v6 quand Types/Profile a « Offline: Offline ».
# a48 : sur un arbre sans Offline dans Types/Profile, relance la copie précédente (a46-banc/autres-bancs/a38-banc) : bonne avant et après la fusion.
if ! grep -q "Offline: Offline" "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a46-banc/autres-bancs/a38-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : colis posés sur les présentoirs : placeBox vise DisplaySlot_xx (setup.luau), StandBox_02 (effects), UnboxState sur DisplaySlot_02 (offers), version attendue v5 (receipts). Objets de départ déplacés hors du présentoir 1 (client, off) ou sur 5 à 7 (Bob et Cid, effects, 3 présentoirs achetés).
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a39-banc/autres-bancs/a38-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a39-banc/autres-bancs/a38-banc/run.sh" "$@"; fi
# Copie d'a39 (2026-11-08, L-071) : vitrine de la boutique Robux (Features.RobuxShopPreview = true au dépôt) → scénario « off » : l'écran s'ouvre en vitrine, sans aucun achat (comme avant si RobuxShopPreview manque) ; scénario « client » : « Soon » 2 s sur une offre à l'Id 0 (reconnu à SOON_TEXT dans RobuxShopController). Bon avant et après la fusion.
# Part de la copie d'a41 (elle-même partie de celle d'a40) : tests.receipts.luau (v4, a40) et tests.effects.luau (tapis sans invite, a41) sont les leurs, tels quels ; seuls tests.off.luau et tests.client.luau changent ici.
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
ROOT="${1:-/f/StealAShop/agents/a39}"
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
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/stub-anticheat.luau" "$H/../../../a53-banc/ext51.luau"
		sources
		if [ "$name" != "off" ]; then cat "$H/pre.on.luau"; fi
		cat "$H/setup.luau" "$H/../../../a53-banc/autres-bancs/compat51.luau"
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

#!/usr/bin/env bash
# Copie d'a67 (2026-11-11, vague 23, L-095 points 1 et 2) : UI_Index_v3 remplace UI_Index_v2 (v2 devient facultatif au contrat : tests.v2contract.luau), écran UI_Settings et SettingsService. Scénarios a67 ajoutés : v3, v3contract, settings (lancés par a67-banc/run.sh) ; ext67.luau complète le faux Roblox (UserInputService, InputBegan, Sound).
# a67 : sur un arbre sans UI_Index_v3 dans Contract/UI, relance la copie précédente (a55-banc/autres-bancs/a40-banc, qui choisit la copie d'a56 ou d'a55) ; les scénarios a67 y sont « SAUTÉ » : bonne avant et après la fusion.
if ! grep -q "UI_Index_v3" "${1:-/f/StealAShop}/src/shared/Contract/UI.luau" 2>/dev/null; then case " ${*:2} " in *v3*|*settings*) echo "banc a40 (index des objets) : SAUTÉ, pas de UI_Index_v3 (a67 pas encore fusionné) : 0 vérification(s), 0 échec(s)"; exit 0;; esac; exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a55-banc/autres-bancs/a40-banc/run.sh" "$@"; fi
# Copie d'a55 de la copie d'a56 (UI_Index_v2), pour un arbre qui a les deux (IndexRewards et UI_Index_v2) : tests.discover.luau et tests.off.luau d'a55 (nouveaux textes), le reste d'a56 ; ext51.luau et compat51.luau d'a53 par chemin. Lancé par ../a40-banc/run.sh.
# Copie d'a53 (2026-11-09, DEV-101) : profil v8 (Rewards) → PROFILE_V = 8 quand Types/Profile a « Rewards: Rewards » (migration et off) ; bonne avant et après la fusion.
# Copie d'a51 (2026-11-09, L-089) : les colis rentrent dans l'inventaire puis se posent au sol (compat51.luau après setup.luau, ext51.luau) ; l'objet ouvert va dans l'inventaire ; version attendue v7 (PROFILE_V), colis du profil v3 retrouvé par son contenu ; faux HttpService déjà dans stubs.luau.
# a51 : sur un arbre d'avant L-089 (sans server/Services/InventoryService.luau), relance la copie précédente (a48-banc/autres-bancs/a40-banc) : bonne avant et après la fusion.
if [ ! -f "${1:-/f/StealAShop}/src/server/Services/InventoryService.luau" ]; then exec bash "$(cd "$(dirname "$0")/../../../" && pwd)/a48-banc/autres-bancs/a40-banc/run.sh" "$@"; fi
# Copie d'a48 (2026-11-08, DEV-102) : profil v6 (Offline, gains hors ligne) → version attendue v6 quand Types/Profile a « Offline: Offline ».
# a48 : sur un arbre sans Offline dans Types/Profile, relance la copie précédente (a46-banc/autres-bancs/a40-banc) : bonne avant et après la fusion.
if ! grep -q "Offline: Offline" "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a46-banc/autres-bancs/a40-banc/run.sh" "$@"; fi
# Copie d'a46 (2026-11-08, L-086) : profil v5 attendu (v6 = « trop récent »), colis posés sur les présentoirs (placeBox de setup.luau), objets ouverts restés sur leur présentoir (2e Donut sur le 3, Carotte de Cid sur le 4, valeur exposée qui en tient compte).
# a46 : sur un arbre d'avant L-086 (sans BoxQueue dans Types/Profile), relance la copie précédente (a40-banc) : bonne avant et après la fusion.
if ! grep -q BoxQueue "${1:-/f/StealAShop}/src/shared/Types/Profile.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")/../../.." && pwd)/a40-banc/run.sh" "$@"; fi
# Banc hors Studio d'a40 (DEV-111, vague 14) : l'index des objets (IndexService, Config/Index, profil v4
# de DataService, bonus additif de DisplayService.GetIncomeBonus avec Premium, délai de révélation
# d'UnboxService.OnBoxOpened, IndexController sur une copie de UI_Index, UI_Index au contrat lu par le
# vrai ContractChecker).
# Vrais : IndexService, DataService (faux ProfileStore d'ext38), DisplayService, PlotService,
# UnboxService, MonetizationService, TrainingService, StatsService, ToolService, ShopService,
# IndexController, UI/Motion, Loader, Net, Config, Contract, Format, Types. Bouchons : TelemetryService,
# CarryService, AntiCheatService, TutorialService (accroche du colis du tuto), PvPService (OnTheftEnded,
# dépôt et échec d'un vol). Faux Roblox : celui d'a38 (stubs.luau d'a36, ext29.luau, ext38.luau).
# Chaque scénario tourne dans son propre luau (état neuf) : features.luau, pre.on.luau (index ouvert,
# boutique Robux branchée) sauf pour « off » (pre.off.luau), setup.luau, puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a40 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a40}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-migration discover off client contract}"
# Arbre d'avant la fusion de DEV-111 (un autre agent lance run-all-bancs.sh sur son worktree) : rien à
# tester, on le dit et on passe.
if [ ! -f "$SRC/server/Services/IndexService.luau" ]; then
	echo "banc a40 (index des objets) : SAUTÉ, pas de IndexService.luau dans $SRC (DEV-111 pas encore fusionné) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/IndexService.luau server/Services/MonetizationService.luau server/Services/DataService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/TrainingService.luau server/Services/UnboxService.luau server/Services/StatsService.luau server/Services/ToolService.luau server/Services/ShopService.luau server/Services/PvPService.luau server/Services/ContractChecker.luau client/Controllers/IndexController.luau client/Controllers/UI/Motion.luau server/Services/SettingsService.luau client/Controllers/SettingsController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

total_checks=0
total_fails=0
for name in $SCENARIOS; do
	: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau" "$H/ext29.luau" "$H/ext38.luau" "$H/stub-anticheat.luau" "$H/../../../a53-banc/ext51.luau" "$H/ext67.luau"
		sources
		cat "$H/features.luau"
		if [ "$name" = "off" ]; then cat "$H/pre.off.luau"; else cat "$H/pre.on.luau"; fi
		cat "$H/setup.luau" "$H/../../../a53-banc/autres-bancs/compat51.luau" "$H/lib67.luau"
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
echo "banc a40 (index des objets) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

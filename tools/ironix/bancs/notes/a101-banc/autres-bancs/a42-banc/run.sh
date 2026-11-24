#!/usr/bin/env bash
# Copie d'a101 (2026-11-12, vague 30, L-110) : BB_ZoneGate retiré du contrat et de ZoneGateController (plus de panneau d'arche), écran UI_ZoneBanner au contrat → tests.gates.luau réécrit (arches suivies, plus rien d'affiché), tests.contract.luau (K2, K8, K13, K15 sur UI_ZoneBanner), setup.luau (buildZoneBannerUi). Sans ZoneBannerController dans l'arbre : la copie d'a94 (bonne avant et après la fusion).
# Copie d'a94 (2026-11-12, L-108 point 5) : G14 (tests.gates.luau) lit « Strength N » de BB_StoreInfo comme « Damage N » de BB_ZoneGate (même valeur, AdvisedDamage). Bonne avant et après la fusion.
# Modifiée par a87 (2026-11-11, demande de Cantin) : fond = playlist Music.AmbientTracks → setup livre aussi les 6 morceaux, tests.chase et tests.music attendent AMB (MUS_Ambient_MorningMood, ou MUS_Ambient avant a87) : pause et reprise du morceau de fond autour de la poursuite, du camion.
# Copie d'a86 (2026-11-11, demande de Cantin) : fond unique MUS_Ambient partout au lieu de MUS_Hub et MUS_Z<n> → setup livre MUS_Ambient ; tests.chase et tests.music attendent MUS_Ambient comme fond (reprise où elle en était), lignes de Studio « la musique de fond continue ». Le reste est la copie d'a71.
# Copie d'a71 (2026-11-11, vague 24) : MUS_Chase monte Config/ChaseFeel.MusicDelay (1,8 s) après le départ de la poursuite
# (0 sans le champ : bonne avant et après la fusion) ; tests.chase.luau et tests.music.luau attendent ce délai après chaque départ
# (sauf C25, reprise pendant le fondu de sortie : sans attente). Le reste est la copie d'a68.
# Copie d'a68 (2026-11-11, vague 23, L-095) : C24 de tests.chase.luau attend MUS_Chase à Config/ChaseFeel.MusicStartAt
# (1,5 s) si le module est dans l'arbre, sinon à 0 s : bonne avant et après la fusion. Le reste est la copie d'a62.
# Copie d'a62 (2026-11-11, vague 22, L-092 3d) : tests.notify.luau lit la durée d'un message dans
# UiMotion.Toast.Hold (2,4 s) quand NotifyController la lit, sinon 4 s. Le reste est tel quel.
# Banc hors Studio d'a42 (vague 14, liaison L-071 points 6 à 9, et colis du camion qui se chevauchaient) :
# poursuite (UI_Chase, ChaseController), musiques d'événement (MUS_Chase, MUS_Truck, MusicController),
# sons et conducteurs du camion (TruckController, TruckEventService), écart entre les colis lâchés et
# invite du colis visé, bandeau de secours et branchement de UI_Notify (NotifyController), panneaux des
# arches (ZoneGateController, BB_ZoneGate, Shared/AdvicePanel commun avec StoreInfoController), contrat
# (Contract/UI, Contract/Models, Contract/Animations lus par le vrai ContractChecker).
# Vrais : Config, Contract, Format, AdvicePanel, Loader, Net, Anim, les contrôleurs et services cités,
# UI/Motion, WindowService, CarryService, ContractChecker. Bouchons : ToolService, StatsService,
# NightCycleService, AnimationController. Faux Roblox : stubs.luau (copie de celui d'a33, complétée).
# Chaque scénario tourne dans son propre luau (état neuf) : pre.<nom>.luau s'il existe, setup.luau,
# puis tests.<nom>.luau.
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : le worktree a42 ; après fusion : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok et la sortie des modules
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
# Avant la fusion d'a86 (pas de Music.AmbientTrack) : le banc d'origine, pour rester bon avant et après.
if [ ! -f "${1:-/f/StealAShop}/src/client/Controllers/ZoneBannerController.luau" ]; then exec bash "$H/../../../a94-banc/autres-bancs/a42-banc/run.sh" "$@"; fi
if ! grep -q AmbientTrack "$ROOT/src/shared/Config/Music.luau" 2>/dev/null; then exec bash "$H/../../../a71-banc/autres-bancs/a42-banc/run.sh" "$@"; fi
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-chase music truck boxes drivers notify gates contract}"
FILES="shared client/Controllers/UI client/Controllers/ChaseController.luau client/Controllers/MusicController.luau client/Controllers/NotifyController.luau client/Controllers/ZoneGateController.luau client/Controllers/ZoneBannerController.luau client/Controllers/StoreInfoController.luau client/Controllers/TruckController.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/TruckEventService.luau server/Services/ContractChecker.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' 2>/dev/null | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$H/stubs.luau"
		sources
		if [ -f "$H/pre.$name.luau" ]; then cat "$H/pre.$name.luau"; fi
		cat "$H/setup.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^scénario .* : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -15
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
echo "banc a42 (poursuite, camion, notifications, arches) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

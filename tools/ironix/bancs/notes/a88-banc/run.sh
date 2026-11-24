#!/usr/bin/env bash
# Banc hors Studio d'a88 (2026-11-11, vague 28, L-085 et L-097 point 4) : potions côté serveur (PotionService).
# Vrais : PotionService, SkillTreeService, PvPService, WindowService, DisplayService, PlotService, CarryService,
# Net, Config, Contract, Format, Types, Loader. Bouchons : ceux du banc a29 (copie d'a36 : DataService,
# ToolService, StatsService, AntiCheatService), NightCycleService (a29 + IsNight et IsInCorridor, lib88),
# TelemetryService et GuardService (pre88), AaBoostService (accroches ×3 de « Cy » chargées avant les potions).
# Faux Roblox et mise en place lus sur place dans a36-banc/autres-bancs/a29-banc (stubs.luau, ext29.luau,
# setup.luau). Le scénario guard tourne sur le vrai GuardService (guard/run.sh).
# Scénarios : spawn (attente, plafond, durée de vie, places, PotionLuck, nuit, réapparition, départ),
# pick (ramassage accepté et refusé), effects (chaque effet et sa fin, cumul, PotionTime, mort, départ,
# accroches gardées), guard (vrai GuardService : invisible, pas repéré par un vigile de nuit).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la fusion d'a88 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../a36-banc/autres-bancs/a29-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-spawn pick effects guard}"
if [ ! -f "$SRC/server/Services/PotionService.luau" ]; then
	echo "banc a88 SAUTÉ : cet arbre n'a pas encore PotionService"
	echo "banc a88 (potions, serveur) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau server/Services/SkillTreeService.luau server/Services/PotionService.luau client/Controllers/PvPController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	if [ "$name" = "guard" ]; then
		out=$(bash "$H/guard/run.sh" "$ROOT" 2>&1)
	else
		{
			if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
			cat "$A29/stubs.luau" "$A29/ext29.luau"
			cat "$A29/../stub-anticheat.luau"
			sources
			cat "$H/pre88.luau"
			cat "$A29/setup.luau"
			cat "$H/lib88.luau"
			cat "$H/tests.$name.luau"
		} > "$OUT"
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	fi
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a88 (potions, serveur) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

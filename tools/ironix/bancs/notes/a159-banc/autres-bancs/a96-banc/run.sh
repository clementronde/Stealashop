#!/usr/bin/env bash
# Copie a159 (2026-11-14, vague 50, L-163) de la copie a134 : porte du bot à PvP.DoorHits (40) coups, panneau « 40/40 », casse en 40 coups au moins, porte de Dan à 40 (presence et theft). Arbre sans PvP.DoorHits : lance la copie a134.
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : dans le faux arbre, la Force reste le levier de dégâts des scénarios et HitWindow garde son débit en rafale (a134-banc/levier-force.luau et coups-en-rafale.luau) ; rien d'autre ne change.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a112-banc/autres-bancs/a96-banc/run.sh" "$@"; fi
# Copie d'a112 (2026-11-13, vague 33) : plus de chrono pour la boutique du bot, aucune alerte d'intrusion. Sans
# PvPService.GetIntruders dans l'arbre, lance la copie d'a99 (bonne avant la fusion).
# Copie d'a99 (2026-11-12, décision de Cantin : plus aucune protection des boutiques) : tests.theft.luau retourné (plus d'immunité du bot après un vol, plus d'anti-racket : Cy le riche casse la porte du bot) ; presence et ext96.luau lus dans le banc d'origine. Sans PvP.KickRobCooldown dans l'arbre, lance le banc d'origine (bon avant et après la fusion).
# Banc hors Studio d'a96 (2026-11-12, vague 29, L-085 point 4, L-105 point 1, L-108 point 3) : le bot joueur.
# Vrais : BotService, PvPService, DisplayService, PlotService, WindowService, CarryService, PvPController, Net,
# Config, Contract, Format, Types, Loader. Bouchons : ceux du banc a29 (copie d'a36 : DataService,
# NightCycleService, ToolService, StatsService, AntiCheatService). Faux Roblox et mise en place lus sur place
# dans a36-banc/autres-bancs/a29-banc (stubs.luau, ext29.luau, setup.luau), complétés dans ext96.luau
# (avatar R15 par défaut, Animator:LoadAnimation, BotService dans l'arbre).
# Scénarios : presence (arrivée sur la dernière boutique libre, objets, porte, avatar, reste à 4 joueurs,
# départ propre au 5e, retour, boutique manquante), theft (panneau, casse, coffre-fort, vol d'un objet du bot,
# dépôt chez soi, rien vers le bot ni les écouteurs, immunité, régénération, vol raté, départ pendant un vol,
# anti-racket).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
# Avant la fusion d'a96 : « SAUTÉ » (0 vérification).
set -u
H="$(cd "$(dirname "$0")" && pwd)"
A29="$H/../../../a112-banc/../a36-banc/autres-bancs/a29-banc"
O96="$H/../../../a112-banc/../a96-banc" # banc d'origine (ext96.luau, tests.presence.luau)
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
if ! grep -q "DoorHits = " "$SRC/shared/Config/PvP.luau" 2>/dev/null; then exec bash "$H/../../../a134-banc/autres-bancs/a96/run.sh" "$ROOT" "$@"; fi
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-presence theft}"
if ! grep -q "function PvPService.GetIntruders" "$SRC/server/Services/PvPService.luau" 2>/dev/null; then
	exec bash "$H/../../../a99-banc/autres-bancs/a96-banc/run.sh" "$ROOT" "$@"
fi
if ! grep -q "KickRobCooldown" "$SRC/shared/Config/PvP.luau" 2>/dev/null; then
	exec bash "$O96/run.sh" "$ROOT" "$@"
fi
if [ ! -f "$SRC/server/Services/BotService.luau" ]; then
	echo "banc a96 SAUTÉ : cet arbre n'a pas encore BotService"
	echo "banc a96 (bot joueur) : 0 vérification(s), 0 échec(s)"
	exit 0
fi
FILES="shared server/Services/BotService.luau server/Services/PvPService.luau server/Services/DisplayService.luau server/Services/PlotService.luau server/Services/WindowService.luau server/Services/CarryService.luau client/Controllers/PvPController.luau"

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

OUTDIR="$(mktemp -d)"
trap 'rm -rf "$OUTDIR"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$OUTDIR/run.$name.luau"
	{
		if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
		cat "$A29/stubs.luau" "$A29/ext29.luau"
		cat "$A29/../stub-anticheat.luau"
		sources
		cat "$H/../../levier-force.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../coups-en-rafale.luau" # a134 : faux arbre, voir ce fichier
		cat "$A29/setup.luau"
		cat "$O96/ext96.luau"
		if [ -f "$H/tests.$name.luau" ]; then cat "$H/tests.$name.luau"; else cat "$O96/tests.$name.luau"; fi
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
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|^    " || true
	fi
	c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a96 (bot joueur) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

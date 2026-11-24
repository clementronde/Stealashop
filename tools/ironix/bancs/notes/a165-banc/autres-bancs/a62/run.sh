#!/usr/bin/env bash
# Copie a165 (2026-11-14, vague 51) : le chrono fini garde sa dernière couleur pendant le fondu → R1e et R2c attendent
# le rouge, R3 ajouté. Arbre sans a165 (pas de POLICE_TEXT_COLOR dans HudController) : la copie a134 telle quelle.
_A165_R="${1:-/f/StealAShop}"
if ! grep -q "POLICE_TEXT_COLOR" "$_A165_R/src/client/Controllers/HudController.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a134-banc/autres-bancs/a62/run.sh" "$@"; fi
# Copie a134 (2026-11-14, vague 40, rééquilibrage v2 appliqué dans src/) : plus de gain « +X Power » (plus de banc ni de Force) ; faux arbre : levier-force.luau et coups-en-rafale.luau.
# Arbre sans le rééquilibrage (Balance.Stats.WalkPerDecade absent) : le banc d'avant tourne tel quel.
_A134_R="${1:-/f/StealAShop}"; _A134_F="$_A134_R/src/shared/Config/Balance.luau"; [ -f "$_A134_F" ] || _A134_F="$_A134_R/shared/Config/Balance.luau"
if ! grep -q "WalkPerDecade" "$_A134_F" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a62-banc/run.sh" "$@"; fi
# Banc hors Studio d'a62 (vague 22, L-092 point 3 : finitions d'UI côté client). Faux Roblox : la copie
# d'a60 rangée dans autres-bancs/a60-banc (stubs, ext-motion, ext-a60 avec InputBegan / InputEnded,
# setup, setup-a60). Vraies sources : Shared, Controllers/UI (Motion), HudController, GainController,
# UiFeelController. Scénarios : touch (3g, bouton remis à 1 à la fin du toucher), banner (3a, RunBanner),
# redtimer (3c, chrono rouge), gainkind (3e, GainKind et couleur de Row.Amount).
#   bash run.sh [racine du dépôt] [scénarios…]   (défaut : /f/StealAShop)
#   VERBOSE=1 bash run.sh                         écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$H/../../../a62-banc/autres-bancs/a60-banc"
ROOT="${1:-/f/StealAShop}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-touch banner redtimer gainkind}"
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"
if ! grep -q "GainKind" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "banc a62 (finitions d'UI, L-092) : SAUTÉ, pas de GainKind dans Config/UiMotion de $SRC (vague 22 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
	exit 0
fi

sources() {
	(cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	{
		cat "$B/stubs.luau" "$B/ext-motion.luau" "$B/ext-a60.luau"
		sources
		cat "$H/../../../a134-banc/levier-force.luau" # a134 : faux arbre, voir ce fichier
		cat "$H/../../../a134-banc/coups-en-rafale.luau" # a134 : faux arbre, voir ce fichier
		cat "$B/setup.luau" "$B/setup-a60.luau"
		cat "$H/tests.$name.luau"
	} > "$OUT"
	out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
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
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a62 (finitions d'UI, L-092) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

#!/usr/bin/env bash
# a198 (vague 61) : copie du banc a155 d a178 ; server.luau : Formulas.MaxWalkSpeed ajouté au faux Config (StatsService le lit).
# Copie a178 (2026-11-15, vague 55) : le « ×2 » du trail en exposant Unicode juste après le nombre (« +1ˣ² Speed/s ») ; T1d, T1e changés, T1g (×1.5) ajouté.
# Banc hors Studio d a155 (2026-11-14, vague 47 : « ×2 » du trail après le gain du tapis). Faux Roblox d a60 (copie a62) avec les ajouts a134 ; scénarios trail (client) et server (StatsService.Refresh pose TrailMultiplier).
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
SCENARIOS="${*:-trail}"
if ! grep -q "Superscript" "$SRC/client/Controllers/GainController.luau" 2>/dev/null; then
	exec bash "$H/../../../a155-banc/run.sh" "$ROOT" "$@" # repli : arbre d avant a178, banc a155 tel quel
fi
FILES="shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau"
if ! grep -q "TrailMultiplierColor" "$SRC/shared/Config/UiMotion.luau" 2>/dev/null; then
	echo "banc a155 (×2 du trail) : SAUTÉ, pas de TrailMultiplierColor dans Config/UiMotion de $SRC (vague 47 pas encore fusionnée) : 0 vérification(s), 0 échec(s)"
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
		awk '{ print } /^	TextScaled = false,$/ { print "	RichText = false, -- a155 : ajout au faux Roblox" }' "$B/stubs.luau"; cat "$H/ext-tohex.luau" "$B/ext-motion.luau" "$B/ext-a60.luau"
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
# Scénario server : vrai StatsService (source lue), faux minimal écrit dans server.luau.
SV="$TMP/server.luau"
{
	printf 'local SOURCE = [==========[\n'; tr -d '\r' < "$SRC/server/Services/StatsService.luau"; printf '\n]==========]\n'
	cat "$H/server.luau"
} > "$SV"
out=$("$LUAU" "$(cygpath -w "$SV")" 2>&1)
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|error" || true
line=$(printf '%s\n' "$out" | grep -E "^[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -10; total_fails=$((total_fails + 1)); else
	c=$(printf '%s' "$line" | sed -E 's/^([0-9]+) vérification.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	echo "  server : $c contrôles, $f raté(s)"; total_checks=$((total_checks + c)); total_fails=$((total_fails + f)); fi
echo "banc a155 (×2 du trail) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

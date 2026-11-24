#!/usr/bin/env bash
# Banc hors Studio d'a250 (restes de la poursuite après fusion68), vrai GuardService sur le harnais d'a193/a249 :
#   porte / porteoff     voleur coincé derrière un panneau de 0,3 stud : porte vitrée et vitrine = un mur (jamais attrapé),
#                        bout de rayon Shelf_A_EndA = traversable pour la règle (attrapé) ; « off » : StuckThinPrefix = ""
#   marche / marcheoff   le vigile longe un bout de rayon à 3 studs/s, à portée : attrapé (a250b) ; à 10 studs/s : jamais
#                        (« off » : StuckProgressShare = 0)
#   detour / detouroff   voleur arrêté derrière un mur, le vigile le contourne par le chemin : attrapé en au plus 2 s
#                        (« off » : ApproachAlongPath = false, ApproachBrakeHidden = 0, mesure d'avant)
#   bash run.sh [racine du dépôt] [scénarios…]   VERBOSE=1 : lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
shift || true
SRC="$ROOT/src"
LUAU="$HOME/.rokit/bin/luau.exe"
SCENARIOS="${*:-porte porteoff marche marcheoff detour detouroff}"
B="$(cd "$H/.." && pwd)"
if ! grep -q "StuckThinPrefix" "$SRC/shared/Config/Chase.luau" 2>/dev/null; then
	echo "banc a250 : SAUTÉ, a250 pas encore fusionné (0 vérification(s), 0 échec(s))"
	exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
total_checks=0
total_fails=0
for name in $SCENARIOS; do
	OUT="$TMP/run.$name.luau"
	bash "$H/assemble.sh" "$SRC" "$H/tests.a250.luau" "$name" > "$OUT"
	pattern="^(scénario .* : )?[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$"
	if grep -q "ShelfOpen = true" "$SRC/shared/Config/Features.luau" 2>/dev/null; then
		out=$("$LUAU" "$(cygpath -w "$OUT")" 2>&1)
	else
		out=$(bash "$B/a172-banc/corrige.sh" a168 bash -c '"$HOME/.rokit/bin/luau.exe" "$1"' _ "$(cygpath -w "$OUT")" 2>&1)
	fi
	line=$(printf '%s\n' "$out" | grep -E "$pattern" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -25
		echo "scénario $name : arrêté avant la fin (erreur ci-dessus)"
		total_fails=$((total_fails + 1))
		continue
	fi
	if [ "${VERBOSE:-}" = "1" ]; then
		printf '%s\n' "$out"
	else
		printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|échoue|ÉCHOUÉ|^  mesure" || true
	fi
	c=$(printf '%s' "$line" | grep -oE "[0-9]+ vérification" | grep -oE "[0-9]+")
	f=$(printf '%s' "$line" | grep -oE "[0-9]+ échec" | grep -oE "[0-9]+")
	echo "  $name : $c contrôles, $f raté(s)"
	total_checks=$((total_checks + c))
	total_fails=$((total_fails + f))
done
echo "banc a250 (poursuite, restes de fusion68 : porte, vigile qui marche, détour) : $total_checks vérification(s), $total_fails échec(s)"
exit $((total_fails > 0))

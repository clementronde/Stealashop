#!/usr/bin/env bash
# a305 (22/11, Cantin 2026-11-21 : Balance.Heist.Duration de 6 à 10 s, chrono HEIST) : copie du banc a135 ; la partie heist
# passe par tests.heist.luau de ce dossier (P0a attend 10, libellés à 10 s ; P2d, P3a et P3b lisaient déjà Heist.Duration) ;
# hud et profiles : ceux d'a135 tels quels (le HUD reçoit des chronos fabriqués, sans lire Heist.Duration).
# Arbre encore à Duration = 6 : le banc a135 d'avant tel quel.
#   bash run.sh [racine du dépôt]   (défaut : /f/StealAShop)
set -u
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
if grep -qE "^[[:space:]]*Duration = 6," "$ROOT/src/shared/Config/Balance.luau" 2>/dev/null; then
	exec bash "$B/a135-banc/run.sh" "$ROOT"
fi
checks=0
fails=0
for part in heist hud profiles; do
	if [ "$part" = "heist" ]; then dir="$H"; else dir="$B/a135-banc"; fi
	out=$(bash "$dir/run-$part.sh" "$ROOT" 2>&1)
	printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|SAUTÉ" || true
	line=$(printf '%s\n' "$out" | grep -E "[0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
	if [ -z "$line" ]; then
		printf '%s\n' "$out" | tail -10
		fails=$((fails + 1))
		continue
	fi
	c=$(printf '%s' "$line" | sed -E 's/^(.* )?([0-9]+) vérification.*/\2/')
	f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
	checks=$((checks + c))
	fails=$((fails + f))
done
echo "banc a135 (braquage, police, profils) : $checks vérification(s), $fails échec(s)"
exit $((fails > 0))

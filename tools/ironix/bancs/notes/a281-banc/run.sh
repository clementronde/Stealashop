#!/usr/bin/env bash
# Banc a281 (vague GC3, 23/11, audit a271 point 1) : foule, Crowd.Cull et Crowd.ViewDistanceLow.
#   bash run.sh [racine du dépôt]   VERBOSE=1 : écrit aussi les lignes ok
set -u
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop}"
ROOT="${ROOT%/src}"
NAME="banc a281 (foule hors écran ou loin)"
out=$(timeout 300 bash "$H/crowd-run.sh" "$ROOT" 2>&1)
if printf '%s\n' "$out" | grep -q "SAUTÉ"; then echo "$NAME : SAUTÉ, 0 vérification(s), 0 échec(s)"; exit 0; fi
printf '%s\n' "$out" | grep -E "ÉCHEC|ERREUR|rror|MESURE" | sed "s/^/  crowd /"
line=$(printf '%s\n' "$out" | grep -E "^banc a281 crowd : [0-9]+ vérification\(s\), [0-9]+ échec\(s\)$" | tail -1)
if [ -z "$line" ]; then printf '%s\n' "$out" | tail -15; echo "$NAME : 0 vérification(s), 1 échec(s)"; exit 1; fi
c=$(printf '%s' "$line" | sed -E 's/.* : ([0-9]+) vérif.*/\1/'); f=$(printf '%s' "$line" | sed -E 's/.*, ([0-9]+) échec.*/\1/')
echo "$NAME : $c vérification(s), $f échec(s)"
exit $((f > 0))

#!/usr/bin/env bash
# a174 (2026-11-15, vague 54) : lanceur du banc a114 (copie a158). Avec a174 (Chase.ReturnToShelfAfterCatches), le retour
# au rayon à la 3e capture est coupé pour ce banc (a174-banc/patches/a114.sed : L2 à L4 attrapent 4 fois le même objet ;
# la 3e capture est vérifiée par le banc a174). Sans a174 : le lanceur d'a158 tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "ReturnToShelfAfterCatches" "$REPO/src/shared/Config/Chase.luau" 2>/dev/null; then
	exec bash "$H/a158-banc/autres-bancs/a114/run.sh" "$@"
fi
exec bash "$H/a174-banc/corrige.sh" a114 bash "$H/a158-banc/autres-bancs/a114/run.sh" "$@"

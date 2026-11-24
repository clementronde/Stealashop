#!/usr/bin/env bash
# a208 (2026-11-16, vague 63) : lanceur du banc a39 (celui d'a183) corrigé par ../../patches/a39.sed (6 packs d'argent,
# boosts du HUD dans l'onglet Boosts). Arbre sans Cash720 dans Config/Monetization (avant la fusion) : le lanceur d'avant.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q 'Cash720' "$REPO/src/shared/Config/Monetization.luau" 2>/dev/null; then
	exec bash "$H/a183-banc/autres-bancs/a39/run.sh" "$@"
fi
exec bash "$H/a208-banc/corrige.sh" a39 bash "$H/a183-banc/autres-bancs/a39/run.sh" "$@"

#!/usr/bin/env bash
# a420 (24/11, Chase.ClientView.Contact) : le banc a416 sur le harnais d'a420 (tests.a420.luau = tests.a416.luau + U29
# revu : voleur à l'arrêt, point visé au-delà de lui → il vise StandOff studs avant ; U29b : voleur qui court, inchangé ;
# U39 à U47 : Brake, Announced, StuckSeen). Arbre sans a420 (pas de « Contact = { » dans Config/Chase) : le lanceur
# d'avant (lot98-banc/autres-bancs/a416, copie à BaseSeconds 0,25).
set -u
N="$(cd "$(dirname "$0")/../../.." && pwd)"
ROOT="${1:-/f/StealAShop}"; ROOT="${ROOT%/src}"; shift || true
if grep -q "Contact = {" "$ROOT/src/shared/Config/Chase.luau" 2>/dev/null; then
	SCEN="${*:-${A416_SCENARIOS:-unite zones zonesavant}}"
	# shellcheck disable=SC2086
	exec bash "$N/a420-banc/run.sh" "$ROOT" $SCEN
fi
exec bash "$N/lot98-banc/autres-bancs/a416/run.sh" "$ROOT" "$@"

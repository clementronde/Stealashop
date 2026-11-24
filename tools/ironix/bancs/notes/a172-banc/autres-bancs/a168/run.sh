#!/usr/bin/env bash
# a172 (2026-11-15, vague 53) : copie de lanceur du banc a168 (et d'a153, qu'il lance sur un arbre sans a168). Leur
# harnais forçait Features.ShelfOpen à false (a103-banc/ancien-deroule.luau) et prenait un colis fermé (grabShelf) :
# l'interrupteur parti, la prise d'un colis fermé est refusée. Le voleur reçoit à la place un objet sorti d'un colis
# du magasin (aide d'a158, patches/a168.pre.luau) : la poursuite mesurée est la même. Arbre avec Features.ShelfOpen :
# le banc tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q "ShelfOpen = true" "$REPO/src/shared/Config/Features.luau" 2>/dev/null; then
	exec bash "$H/a168-banc/run.sh" "$@"
fi
exec bash "$H/a172-banc/corrige.sh" a168 bash "$H/a168-banc/run.sh" "$@"

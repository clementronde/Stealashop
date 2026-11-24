#!/usr/bin/env bash
# a170 (2026-11-15, vague 52, lot D) : lanceur du banc pc-steal. Son garde-fou (bash) relit les appels Model:ScaleTo du
# client ; a170 retire Unbox/Reel et Unbox/Screen (écran d'ouverture en base), donc leurs deux appels. Avant a170 (remote
# BoxReady encore dans Net/Definitions) : pc-steal-banc/run.sh tel quel. Depuis : une copie passagère du même script, avec
# H = pc-steal-banc et la liste relue sans « 1 Reel.luau » ni « 1 Screen.luau ».
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if grep -q 'Name = "BoxReady"' "$REPO/src/shared/Net/Definitions.luau" 2>/dev/null; then
	exec bash "$H/pc-steal-banc/run.sh" "$@"
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
sed -e "s|^H=.*|H=\"$H/pc-steal-banc\"|" -e 's/|1 Reel\.luau|1 Screen\.luau|/|/' "$H/pc-steal-banc/run.sh" > "$T/run.sh"
bash "$T/run.sh" "$@"

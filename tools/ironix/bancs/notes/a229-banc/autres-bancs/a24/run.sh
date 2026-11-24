#!/usr/bin/env bash
# a229 (vague 69) : lanceur du banc a24 (a198-banc/autres-bancs/a24/run.sh) avec les vigiles de nuit posés d'un coup (../../corrige.sh) :
# le banc vérifie les vigiles de nuit juste après la tombée de la nuit ; le rythme d'un par image est vérifié par
# le banc a229. Avant a229 (RefillAll sans « spread ») : le lanceur d'avant tel quel.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
REPO="${ARG%/src}"
if ! grep -q "RefillAll(spread" "$REPO/src/server/Services/StoreHeistService.luau" 2>/dev/null; then
	exec bash "$H/a198-banc/autres-bancs/a24/run.sh" "$@"
fi
exec bash "$H/a229-banc/corrige.sh" bash "$H/a198-banc/autres-bancs/a24/run.sh" "$@"

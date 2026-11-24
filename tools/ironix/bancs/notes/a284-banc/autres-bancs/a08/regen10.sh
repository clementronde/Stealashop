#!/usr/bin/env bash
# a284 : le lanceur du banc a08 d'avant (a262-banc/autres-bancs-cantin/a08/run.sh) sur l'arbre à RegenSyncHz = 10
# (../../regen10.sh) : il compte 10 WindowHP par seconde de régénération ; la cadence de 2 est vérifiée par le banc a284.
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a284-banc/regen10.sh" "$H/a262-banc/autres-bancs-cantin/a08/run.sh" "${1:-/f/StealAShop/src}"

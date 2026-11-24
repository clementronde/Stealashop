#!/usr/bin/env bash
# a285 (21/11) : le lanceur d avant (a262-banc/autres-bancs-cantin/a208/run.sh) sur l arbre où la caisse exclusive est remise pas codée (../../caisse-pas-codee.sh : cas a218 du « Soon »).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$H/a285-banc/caisse-pas-codee.sh" "$H/a262-banc/autres-bancs-cantin/a208/run.sh" "$1"

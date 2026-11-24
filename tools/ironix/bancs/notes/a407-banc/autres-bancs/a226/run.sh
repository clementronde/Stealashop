#!/usr/bin/env bash
# a407 (vague GC6, 23/11) : lanceur d avant du banc a226 (a262-banc/autres-bancs-cantin/a226/run.sh) sur l arbre où Features.RebirthTools = false
# (../../sans-outils.sh : ses tests comptent les 7 armes ordinaires ou les récompenses des renaissances d avant a407).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a407-banc/sans-outils.sh" "$H/a262-banc/autres-bancs-cantin/a226/run.sh" repo "${ARG%/src}"

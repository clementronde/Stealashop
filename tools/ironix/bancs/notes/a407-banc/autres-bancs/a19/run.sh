#!/usr/bin/env bash
# a407 (vague GC6, 23/11) : lanceur d avant du banc a19 (f75-banc/autres-bancs-cantin/a19/run.sh) sur l arbre où Features.RebirthTools = false
# (../../sans-outils.sh : ses tests comptent les 7 armes ordinaires ou les récompenses des renaissances d avant a407).
H="$(cd "$(dirname "$0")/../../.." && pwd)"
ARG="${1:-/f/StealAShop}"
exec bash "$H/a407-banc/sans-outils.sh" "$H/f75-banc/autres-bancs-cantin/a19/run.sh" repo "${ARG%/src}"

#!/usr/bin/env bash
# a171 : le banc a30 (batte) avec ses seuls scénarios repris par a171 (A171_A30 : liste, par défaut drop guard).
H="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$H/a134-banc/autres-bancs/a30/run.sh" "$1" ${A171_A30:-drop guard}

#!/usr/bin/env bash
# lot96 : a171 (copie a297) corrigé par ../../corrige.sh (patches/a171.pl : a38/client, gamepass confirmé par Roblox, a274).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot96-banc/corrige.sh" a171 bash "$N/a297-banc/autres-bancs/a171/run.sh" "$@"

#!/usr/bin/env bash
# lot96 : a181 (copie a262) corrigé par ../../corrige.sh (patches/a181.pl : AncestryChanged du faux Instance, a283).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot96-banc/corrige.sh" a181 bash "$N/a262-banc/autres-bancs-cantin/a181/run.sh" "$@"

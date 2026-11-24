#!/usr/bin/env bash
# lot96 : a38 (copie a274) corrigé par ../../corrige.sh (patches/a38.pl : historique borné = Receipts.History).
N="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$N/lot96-banc/corrige.sh" a38 bash "$N/a274-banc/autres-bancs/a38/run.sh" "$@"

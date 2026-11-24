#!/usr/bin/env bash
# a426 : 2e étape de run.sh (après l'échelle 1 d'a198 et le tapis d'a180) : correctifs a172 et a158 du banc a36, puis
# GuardChaseV2 coupé (a153), comme le banc a36 du lanceur commun ; enfin le harnais d'a426 (autres-bancs/a36z).
H="$(cd "$(dirname "$0")" && pwd)"
B="$(cd "$H/.." && pwd)"
REPO="${1%/src}"
exec bash "$B/a172-banc/corrige.sh" a36 bash "$B/a158-banc/corrige.sh" a36 bash "$B/a153-banc/regle-coupee.sh" "$H/autres-bancs/a36z/run.sh" repo "$REPO"

#!/usr/bin/env bash
# a422 : diagnostic (pas un banc) : moments des sons de l'encaissement avec la config du jeu. bash run-diag.sh [racine] [fichier de scénario]
set -u
H="$(cd "$(dirname "$0")/.." && pwd)"
D="$(cd "$H/.." && pwd)"
B60="$D/a62-banc/autres-bancs/a60-banc"; A75="$D/a75-banc"; A80="$D/a80-banc"
ROOT="${1:-/f/StealAShop/agents/a422}"; SRC="${ROOT%/src}/src"
SCEN="${2:-$H/diag/diag.luau}"
sources() { (cd "$SRC" && find "$@" -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.diag.luau"
{ cat "$B60/stubs.luau" "$B60/ext-motion.luau" "$B60/ext-a60.luau" "$A75/ext-a75.luau" "$A80/ext-a80.luau" "$H/ext-a401.luau"
  sources shared client/Controllers/UI client/Controllers/HudController.luau client/Controllers/GainController.luau client/Controllers/UiFeelController.luau client/Controllers/NotifyController.luau client/Controllers/VfxController.luau client/Controllers/CollectFeelController.luau
  cat "$H/pre-a401.luau" "$B60/setup.luau" "$B60/setup-a60.luau" "$A75/setup-a75.luau" "$SCEN"; } > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")" 2>&1 | grep -v '^LOG'

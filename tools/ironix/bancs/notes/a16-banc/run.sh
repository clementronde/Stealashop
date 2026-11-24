#!/usr/bin/env bash
# Banc d'essai hors Studio de la casse de vitrine (DEV-016, agent a16).
# Assemble les bouchons, les sources du dépôt et les scénarios en un seul fichier Luau, puis l'exécute.
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop/agents/a16 ; après fusion : /f/StealAShop
#   VERBOSE=1 bash run.sh             écrit aussi toute la sortie des modules
# Le fichier assemblé va dans un dossier temporaire (rien n'est écrit à côté de ce script).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a16}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  (cd "$SRC" && { find shared -name '*.luau'; echo server/Services/WindowService.luau; echo client/Controllers/WindowController.luau; echo client/Controllers/ShatterController.luau; echo client/Controllers/HitController.luau; } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"

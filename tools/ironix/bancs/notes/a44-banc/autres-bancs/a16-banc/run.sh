#!/usr/bin/env bash
# Copie a44 (vague 15, L-081) : la vitre se creuse au lieu des étoiles de fissure → faux GeometryService et UserInputService (../../ext-carve.luau), vérifications des étoiles remplacées par celles du creux ; le reste est inchangé.
# Banc d'essai hors Studio de la casse de vitrine (DEV-016, agent a16).
# Assemble les bouchons, les sources du dépôt et les scénarios en un seul fichier Luau, puis l'exécute.
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop/agents/a16 ; après fusion : /f/StealAShop
#   VERBOSE=1 bash run.sh             écrit aussi toute la sortie des modules
# Le fichier assemblé va dans un dossier temporaire (rien n'est écrit à côté de ce script).
set -eu
# a44 : arbre sans le creux (avant la fusion de la vague 15) → la copie précédente (a34) tourne telle quelle.
if ! grep -q "Carve = {" "${1:-/f/StealAShop/agents/a16}/src/shared/Config/Shatter.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a34-banc/autres-bancs/a16-banc/run.sh" "$@"; fi
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a16}"
SRC="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  cat "$H/../../ext-carve.luau" # a44 : GeometryService, UserInputService, Reflectance
  (cd "$SRC" && { find shared -name '*.luau'; echo server/Services/WindowService.luau; echo client/Controllers/WindowController.luau; echo client/Controllers/ShatterController.luau; echo client/Controllers/HitController.luau; } | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
W="$OUT"
if command -v cygpath >/dev/null 2>&1; then W="$(cygpath -w "$OUT")"; fi
"$HOME/.rokit/bin/luau.exe" "$W"

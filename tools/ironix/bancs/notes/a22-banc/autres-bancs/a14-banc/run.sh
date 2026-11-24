#!/usr/bin/env bash
# Banc d'essai hors Studio de DisplayService et DisplayController (DEV-020, agent a14) ; copie adaptée
# par a22 au catalogue v2 (objets retirés remplacés, noms anglais, ModelStreamingMode dans le faux Roblox).
# Assemble les bouchons, les sources du dépôt et les scénarios en un seul fichier Luau, puis l'exécute.
#   bash run.sh [racine du dépôt]     défaut : /f/StealAShop/agents/a14 ; après fusion : /f/StealAShop
#   VERBOSE=1 bash run.sh             écrit aussi toute la sortie des modules
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a22}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
{
  if [ "${VERBOSE:-}" = "1" ]; then echo "VERBOSE = true"; fi
  cat "$H/stubs.luau"
  (cd "$SRC" && find shared server/Services/DisplayService.luau client/Controllers/DisplayController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

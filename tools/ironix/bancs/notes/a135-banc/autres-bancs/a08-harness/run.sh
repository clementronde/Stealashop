#!/usr/bin/env bash
# Copie a135 (vague 40, 2026-11-14, Cantin : braquage de 6 s) : reconstruction de la vitrine attendue à Balance.Heist.Duration + Balance.Window.RebuildDelay (26 s) au lieu de 30 s (bonne avant et après la fusion). Le reste : copie a93.
# Copie a93 (2026-11-12, vague 29, L-106 point 3) : la porte d'une parcelle a la base de son niveau de boutique (50 au niveau 1) et non plus 50 × les dégâts du propriétaire ; deux contrôles attendent 50.
# Assemble les bouchons, les sources du worktree et les scénarios en un seul fichier Luau, puis l'exécute.
set -eu
# a93 : arbre sans la nouvelle formule des PV de porte (avant la fusion d'a93) → la copie a30 tourne telle quelle.
if ! grep -q "function Formulas.PlayerWindowHP(stageLevel" "${1:-/f/StealAShop/agents/a08/src}/shared/Config/Formulas.luau" 2>/dev/null; then exec bash "$(cd "$(dirname "$0")" && pwd)/../../../a30-banc/autres-bancs/a08-harness/run.sh" "$@"; fi
H="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-/f/StealAShop/agents/a08/src}"
OUT="$(mktemp -d)/run.luau" # copie a93 : hors du dossier du banc
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find shared server/Services client -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

#!/usr/bin/env bash
# Banc hors Studio de a21 (DEV-047 nuit, DEV-045 Retour base) : NightCycleService, vigiles de nuit
# (GuardService), ReturnBaseService, avec les vrais Net, Config, Contract, Format, AnimPlayer,
# MarkerSounds et ChaseController. Faux Roblox : celui de a12 (copie de a15), complété (groupes de
# collision, heure serveur, DescendantAdded, Lighting, côté « prod » hors Studio).
#   bash run.sh [racine du dépôt]   (défaut : le worktree a21 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a21}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/GuardService.luau server/Services/NightCycleService.luau server/Services/ReturnBaseService.luau client/Controllers/ChaseController.luau"
{
  cat "$H/stubs.luau"
  printf '\nRIG_MODE = "roblox"\n'
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.head.luau" "$H/scenarios.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

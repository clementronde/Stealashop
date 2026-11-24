#!/usr/bin/env bash
# Copie d'a94 (2026-11-12, L-108 point 2) : vigiles de nuit à Night.ChaseSpeed (80) et Run bornée à Night.GaitSpeedMax (4) ; tests.luau lit ces champs (sinon vitesse conseillée + 4 et 1,6) : bonne avant et après la fusion.
# Copie d'a66 (2026-11-11, poursuite sans fin) : B2 vérifie que le vigile poursuit encore au-delà de 124 studs (sans GiveUpChaseDuration dans Config/Balance ; sinon l'ancien contrôle : bonne avant et après la fusion).
# Copie d'a36 (vague 12, DEV-060) : bouchon d'AntiCheatService (../stub-anticheat.luau), requis par les services qui déplacent un joueur.
# Banc hors Studio de a24 (vague 7) : les vigiles de Clément (Guard_Z1 à Guard_Z6) dans
# GuardService. Taille et agent du PathfindingService, capture et abandon d'un grand vigile, rythme
# de Run et de Walk, dossiers Animations vides, vigiles de nuit, AnimPlayer.AdjustSpeed.
# Vrais : GuardService, Net, Config, Contract, Format, AnimPlayer, MarkerSounds. Bouchons :
# CarryService, StatsService. Faux Roblox : celui de a21-banc/night (copie dans stubs.luau),
# complété dans stubs.a24.luau.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a24 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a24}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
FILES="shared server/Services/GuardService.luau"
{
  cat "$H/stubs.luau" "$H/stubs.a24.luau"
  cat "$H/../stub-anticheat.luau" # a36 (DEV-060) : bouchon d'AntiCheatService
  printf '\nRIG_MODE = "roblox"\n'
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

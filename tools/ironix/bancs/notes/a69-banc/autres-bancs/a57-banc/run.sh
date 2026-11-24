#!/usr/bin/env bash
# Copie d'a69 (2026-11-11, vague 24, interception) : sur un arbre avec interceptPoint, R1 reprend les contrôles d'a57 (virage vif, plus vif que le témoin sans vitesse, capture au moins aussi rapide) et R2f admet un point jusqu'à 1,5 s devant le joueur, en ligne de vue ; sinon comme la copie d'a66.
# Copie d'a66 (2026-11-11, trajet le plus court sans anticipation) : aussi lancé sur un arbre avec chaseInSight ; R1 y vérifie la reprise de la position au plus toutes les 0,25 s, sans anticipation (vise où est le joueur), et la même poursuite avec ou sans vitesse envoyée ; R2 et R3 inchangés. Sur un arbre d'a57 : les anciens contrôles.
# Banc hors Studio d'a57 (2026-11-10, vague 21, L-091 point 1) : une poursuite qui réagit tout de suite.
# Vrais : GuardService, Shared. Bouchons : CarryService, StatsService, AntiCheatService. Faux Roblox :
# celui d'a54-guard (copie de celui d'a45), préambule de ses tests ; scénarios dans tests.a57.luau.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a57 ; après fusion : /f/StealAShop)
#   FORCE=1 bash run.sh <racine>    lance aussi sur un arbre d'avant a57 (montre l'ancienne poursuite)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a57}"
SRC="$ROOT/src"
OUT="$(mktemp -d)/run.luau"
trap 'rm -rf "$(dirname "$OUT")"' EXIT
FILES="shared server/Services/GuardService.luau"
{
  if [ "${FORCE:-}" = "1" ]; then echo "A57_FORCE = true"; fi
  cat "$H/stubs.luau" "$H/stubs.a24.luau" "$H/stubs.a45.luau"
  cat "$H/stub-anticheat.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.a57.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

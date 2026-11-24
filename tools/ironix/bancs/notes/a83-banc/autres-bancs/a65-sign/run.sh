#!/usr/bin/env bash
# Banc a65, volet panneau (vague 22, 2026-11-11, L-093 point 3) : faux Roblox, réglages et scénario P1
# du banc a52 (UpgradeController réel, côté client), puis le scénario S : le modèle Treadmill de la
# parcelle est remplacé (variante), le panneau UpgradeSign suit le nouvel UpgradePoint.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a65 ; après fusion : /f/StealAShop)
# Copie a83 (2026-11-11, L-096 point 1) : prend la copie a83 du banc a52 (boutique sans StageUpgradePoint).
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
A52="$H/../a52-banc"
ROOT="${1:-/f/StealAShop/agents/a65}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/server/Services/MachineVariantService.luau" ]; then
  echo "a65-sign SAUTÉ : pas de MachineVariantService (a65 pas encore fusionné)"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
end=$(grep -n "^---------------------------------------------------------------- P2" "$A52/tests.luau" | cut -d: -f1)
{
  cat "$A52/stubs.luau"
  (cd "$SRC" && find shared client/Controllers/UpgradeController.luau -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  head -n $((end - 1)) "$A52/tests.luau"
  cat "$H/swap.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

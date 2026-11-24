#!/usr/bin/env bash
# Banc hors Studio de a47 (2026-11-08, L-082 point 2, L-086 point 3) : les rayons de présentoirs de la
# boutique apparaissent avec les achats (RayonService) et l'invite « Unlock stand » reste atteignable
# (UpgradeController). Faux Roblox : copie de celui d'a45, complétée (stubs.luau, blocs « ajouts a47 »).
# Avant la fusion d'a47 (pas de RayonService dans l'arbre) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a47 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a47}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/server/Services/RayonService.luau" ]; then
  echo "a47 SAUTÉ : cet arbre n'a pas encore RayonService"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau client/Controllers/UpgradeController.luau"
# ajout a83 (2026-11-11, L-096) : RayonService requiert ShopStageService après la fusion d'a83.
if [ -f "$SRC/server/Services/ShopStageService.luau" ]; then FILES="$FILES server/Services/ShopStageService.luau"; fi
{
  cat "$H/stubs.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

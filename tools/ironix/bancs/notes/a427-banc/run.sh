#!/usr/bin/env bash
# Banc hors Studio d'a427 (lot100, L-321 : Floor_2 livré) : socles et plaques de l'étage cachés tant que leur place
# n'est pas achetée (RayonService, bonus 21 à 24 selon GetExtraSlots), Shared/ShopFloor.StandAt et
# ShopBuildPlan.newStands (présentoir construit « en mode Lego » à chaque achat, étage compris). Repose sur le faux
# Roblox et la boutique du banc a280 (part-harness), avec un Floor_2 au plan livré.
#   bash run.sh [racine du dépôt]   (défaut : le worktree a427)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a427}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/shared/ShopFloor.luau" ]; then
  echo "a427 SAUTÉ : cet arbre n'a pas encore Shared/ShopFloor"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau server/Services/ShopWallsService.luau client/Controllers/UpgradeController.luau"
{
  cat "$H/../a52-banc/stubs.luau"
  cat "$H/../a127-banc/autres-bancs/a83-banc/ext-a83.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/../a280-banc/part-harness.luau"
  cat "$H/part-scenarios.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

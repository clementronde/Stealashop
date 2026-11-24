#!/usr/bin/env bash
# Banc hors Studio d'a280 (vague GC2, lot C de l'audit a270 ; L-217, L-231, L-277) : 2e étage Floor_2. Règles de
# Shared/ShopFloor (places ouvertes, débloquées, prochain présentoir, prix, « Stands x/y »), ShopStageService
# (copie du Floor_2 du gabarit, rangée hors de la boutique puis montrée, jamais détruite ; FloorStands ; FloorSlots ;
# Floor_2 posé dans la boutique), RayonService (règle de L-294 : 8 présentoirs en bas, étage acheté, rangé à la
# renaissance et au départ), ShopFloor.Migrate et ShopWallsService (HideFromSkill, Look_n). Préambule du banc rowcut. Avant a280 (pas de
# Shared/ShopFloor) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a280)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a280}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/shared/ShopFloor.luau" ]; then
  echo "a280 SAUTÉ : cet arbre n'a pas encore Shared/ShopFloor"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau server/Services/ShopWallsService.luau client/Controllers/UpgradeController.luau"
{
  cat "$H/../a52-banc/stubs.luau"
  cat "$H/../a127-banc/autres-bancs/a83-banc/ext-a83.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/part-harness.luau"
  cat "$H/part-scenarios.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"

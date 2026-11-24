#!/usr/bin/env bash
# Banc hors Studio de a179 (2026-11-15, vague 55) : la boutique du joueur grandit petit à petit (ShopStageService
# coupe ses copies Stage_j au fond du dernier présentoir débloqué, Config/ShopGrowth ; RayonService cache les
# socles au-delà ; UpgradeController suit le point StageUpgradePoint_2 qui avance). Gabarit de test à la géométrie
# de Clément (L-141 : porte z −40, fond z 40, rangs tous les 7 studs). Faux Roblox : celui d'a52 + ext-a83.
# Avant la fusion d'a179 (pas de Config/ShopGrowth dans l'arbre) : « SAUTÉ ».
#   bash run.sh [racine du dépôt]   (défaut : le worktree a179 ; après fusion : /f/StealAShop)
set -eu
H="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/f/StealAShop/agents/a179}"
SRC="$ROOT/src"
: "${R1_D:=$(d="${R1_RUN:-${TMPDIR:-/tmp}/r1-bancs}"; mkdir -p "$d" && mktemp -d "$d/b.XXXXXX")}" "${R1_D:?r1 : dossier du banc introuvable}"; OUT="$R1_D/run.luau"
if [ ! -f "$SRC/shared/Config/ShopGrowth.luau" ]; then
  echo "a179 SAUTÉ : cet arbre n'a pas encore Config/ShopGrowth"
  echo "0 vérification(s), 0 échec(s)"
  exit 0
fi
FILES="shared server/Services/RayonService.luau server/Services/ShopStageService.luau client/Controllers/UpgradeController.luau"
{
  cat "$H/../a52-banc/stubs.luau"
  cat "$H/../a127-banc/autres-bancs/a83-banc/ext-a83.luau"
  (cd "$SRC" && find $FILES -name '*.luau' | sort) | awk -v root="$SRC" '{ f = $0; p = root "/" f; rs = RS; RS = "^$"; c = ""; getline c < p; close(p); RS = rs; gsub(/\r/, "", c); printf "SOURCES[\"%s\"] = [==========[\n%s\n]==========]\n", f, c }'
  cat "$H/tests.luau"
} > "$OUT"
"$HOME/.rokit/bin/luau.exe" "$(cygpath -w "$OUT")"
